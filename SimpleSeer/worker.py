
from celery import Celery
from celery import task
from celery.exceptions import RetryTaskError
from celery.contrib import rdb
from celery.result import ResultSet

from bson import ObjectId
from gridfs import GridFS

from .util import ensure_plugins 
from .base import jsonencode, jsondecode

from .realtime import ChannelManager
from . import models as M
from .Session import Session

from celery.utils import log
log = log.get_task_logger(__name__)
import logging

from . import celeryconfig
celery = Celery()
celery.config_from_object(celeryconfig)
            
from collections import defaultdict
            
ensure_plugins()

"""
Legacy function for VQL backfill handler
"""
@task()
def backfill_meta(frame_id, inspection_ids, measurement_ids, tolerance_ids):
    from SeerCloud.OLAPUtils import RealtimeOLAP
    from SeerCloud.models.OLAP import OLAP
    from .Filter import Filter
    
    try:
        f = M.Frame.objects.get(id = frame_id)
        
        # Scrubber may clear old images from frames, so can't backfill on those
        if f.imgfile:
            for i_id in inspection_ids:
                try:
                    i = M.Inspection.objects.get(id=i_id)
                    
                    if not i.parent:
                        if not i.camera or i.camera == f.camera: 
                            f.features += i.execute(f)
                except Exception as e:
                    print 'Error on inspection %s: %s' % (i_id, e)
                    
            for m_id in measurement_ids:
                try:
                    m = M.Measurement.objects.get(id=m_id)
                    m.execute(f, f.features)
                except Exception as e:
                    print 'Error on measurement %s: %s' % (m_id, e)
            
            for m_id in tolerance_ids:
                try:
                    m = M.Measurement.objects.get(id=m_id)
                    m.tolerance(f, f.results)
                except Exception as e:
                    print 'Error on tolerance %s: %s' % (m_id, e)
                
            f.save(publish=False)    
            
            # Need the filter format for realtime publishing
            ro = RealtimeOLAP()
            ff = Filter()
            allFilters = {'logic': 'and', 'criteria': [{'type': 'frame', 'name': 'id', 'eq': frame_id}]}
            res = ff.getFrames(allFilters)[1]
            
            for m_id in measurement_ids:
                try:
                    m = M.Measurement.objects.get(id=m_id)
                    
                    # Publish the charts
                    charts = m.findCharts()
                    for chart in charts:
                        olap = OLAP.objects.get(name=chart.olap)
                        data = ff.flattenFrame(res, olap.olapFilter)
                        data = chart.mapData(data)
                        ro.sendMessage(chart, data)
                except Exception as e:
                    print 'Could not publish realtime for %s: %s' % (m_id, e)
            
        else:
            print 'no image on frame.  skipping'
    except Exception as e:
        print 'Error on frame %s: %s' % (frame_id, e)        
    
    print 'Backfill done on %s' % frame_id
    return frame_id

class InspectionLogHandler(logging.Handler):

    def __init__(self):
        super(InspectionLogHandler, self).__init__()
        
    def emit(self, msg):
        from .realtime import ChannelManager
        
        insp = self._getInspectionId(msg.msg)
        if insp:
            fra = self._getFrame(msg.msg)
            if fra:
                # This should be doing an update of the feature history log
                pass
                
    def _getInspectionId(self, msg):
        # Assume the first 24 digits is inspection id
        potentialId = msg[:24]
        if ObjectId.is_valid(potentialId):
            insp = M.Inspection.objects(id=potentialId)
            if insp:
                return insp[0].id
        
        return None
        
    def _getFrame(self, msg):
        # Assume the first 24 digits is inspection id
        potentialId = msg[25:49]
        if ObjectId.is_valid(potentialId):
            fra = M.Frame.objects(id=potentialId)
            if fra:
                return fra[0].id
        
        return None
        
            

class Foreman():
# Manages a lot of worker-related tasks
# This is a borg (speed worker status, plugin checks)

    _useWorkers = False
    _initialized = False
    _inspectionLog = None
    
    __sharedState = {}
    
    def __init__(self):
        from .realtime import PubSubHandler
            
        self.__dict__ = self.__sharedState
            
        if not self._initialized:
            self._useWorkers = self.workerRunning()
            self._initialized = True
            ensure_plugins()
            
            log.addHandler(PubSubHandler())
            log.addHandler(InspectionLogHandler())
            log.setLevel(20) # INFO 

    def workerRunning(self):

        if Session().disable_workers:
            return False 

        i = celery.control.inspect()
        if i.active_queues() is not None:
            return True
        else:
            return False

    def process_inspections(self, frame, inspections=None):
        inspKwargs = {'parent__exists': False}
        if inspections:
            inspKwargs['id__in'] = inspections
        
        insps = M.Inspection.objects(**inspKwargs)
        
        # Because it is too big a pain to do an OR with mongoengine:
        filteredInsps = []
        for i in insps:
            if i.camera == frame.camera or not i.camera:
                filteredInsps.append(i)
        
        if self._useWorkers:
            return self.worker_inspection_iterator(frame, filteredInsps)    
        else:
            return self.serial_inspection_iterator(frame, filteredInsps)

    def process_measurements(self, frame, measurements=None):
        measKwargs = {}
        
        if frame.features:        
            # only measurements for which there is a matching feature...
            # exact format of feature object depends on whether it came from worker or serial
            insps = { feat.inspection: 1 for feat in frame.features }.keys()
            measKwargs['inspection__in'] = insps
        else:
            # No features, but limit measurements to those associated with features on this camera
            measKwargs['inspection__in'] = [ insp.id for insp in M.Inspection.objects(camera=frame.camera) ]
            
        if measurements:
            measKwargs['id__in'] = measurements
        
        filteredMeass = M.Measurement.objects(**measKwargs)
        
        if self._useWorkers:
            return self.worker_measurement_iterator(frame, filteredMeass)
        else:
            return self.serial_measurement_iterator(frame, filteredMeass)

    def worker_inspection_iterator(self, frame, insps):
        sched = self.worker_x_schedule(frame, insps, self.inspection_execute)
        return self.worker_x_iterator(sched)
        
    def worker_measurement_iterator(self, frame, meass):
        sched = self.worker_x_schedule(frame, meass, self.measurement_execute)
        return self.worker_x_iterator(sched)
            
    def worker_x_schedule(self, frame, objs, fn):
        scheduled = ResultSet([])
        for o in objs:
            scheduled.add(fn.delay(frame, o))
        return scheduled
            
    def worker_x_iterator(self, scheduled):
        for output in scheduled:
            for out in output:
                for key in out._data.keys():
                    out._changed_fields.append(key)
                yield out
        
    def serial_inspection_iterator(self, frame, insps):
        for i in insps:
            try:
                features = i.execute(frame)
            except:
                features = []
            for feat in features:
                yield feat
                
    def serial_measurement_iterator(self, frame, meass):
        for m in meass:
            results = m.execute(frame)
            
            for res in results:
                for key in res._data.keys():
                    res._changed_fields.append(key)
                yield res

    @task
    def inspection_execute(frame, inspection):
        print 'working'
        try:
            log.warn('{} Inspecting {}'.format(inspection.id, frame.id))
            try:
                features = inspection.execute(frame)
            except:
                return []
            return features        
        except Exception as e:
            log.error(e)
            print e
            return []

    @task
    def measurement_execute(frame, measurement):
        try:
            log.warn('{} Measuring {}'.format(measurement.id, frame.id))
            #frame = M.Frame.objects.get(id=fid)
            #measurement = M.Measurement.objects.get(id=mid)
            results = measurement.execute(frame)
            return results        
        except Exception as e:
            log.error(e)
            return []
            
