
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
                # Which we currently do not worry about doing
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
        # Checks once to see if worker is running (self.workerRunning)
        # Add a special log handler for tracking inspection results
        
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

        # Disable workers is set in the config.
        # Prevents the use of workers for inspections even if worker process is running
        if Session().disable_workers:
            return False 

        # To test if worker is running, see if Celery has any queues.  This returns an empty list if not running
        i = celery.control.inspect()
        if i.active_queues() is not None:
            return True
        else:
            return False

    def process_inspections(self, frame, inspections=None):
        """
        Pass the frame to inspect and an optional list of inspections to run.  
        If no list of inspections passed, run all matching inspections.
        Matching inspections defined by:
        - Does not have a parent inspection (child inspections run by their parent)
        - The inspection's camera field matches the frame's camera field, or the inspections camera is not set
        
        Returns an interator for a list of features
        """
        
        inspKwargs = {'parent__exists': False}
        if inspections:
            inspKwargs['id__in'] = inspections
        
        insps = M.Inspection.objects(**inspKwargs)
        
        # Do this as a loop because it is too big a pain to do an OR with mongoengine:
        filteredInsps = []
        for i in insps:
            if i.camera == frame.camera or not i.camera:
                filteredInsps.append(i)

        # Run the inspections
        if self._useWorkers:
            return self.worker_inspection_iterator(frame, filteredInsps)    
        else:
            return self.serial_inspection_iterator(frame, filteredInsps)

    def process_measurements(self, frame, measurements=None):
        """
        Pass a frame, which also contains the list of frame features to be measured
        Optionally, provide a list of measurements.  If not use the default measurement selection criteria
        which select measurements that reference the inspections that ran on the frame.
        
        Note: some measurements return results if an inspection returned no features, so do not filter
        on measurements matching frame features
        """
        
        measKwargs = {}

        # Get the list of inspections that could have run on this frame
        inspKwargs = {'parent__exists': False}
        insps = M.Inspection.objects(**inspKwargs)
        
        filteredInspIds = []
        for i in insps:
            if i.camera == frame.camera or not i.camera:
                filteredInspIds.append(i.id)

        measKwargs['inspection__in'] = filteredInspIds
            
        if measurements:
            measKwargs['id__in'] = measurements
        
        filteredMeass = M.Measurement.objects(**measKwargs)
        
        # Run the measurements
        if self._useWorkers:
            return self.worker_measurement_iterator(frame, filteredMeass)
        else:
            return self.serial_measurement_iterator(frame, filteredMeass)

    def worker_x_schedule(self, frame, objs, fn):
        """
        - For each object (a list of measurements or inspection)
        - Run the specified function (fn)
        - On the specified frame
        - Using workers
        
        Returns a celery resultset of tasks that are scheduled to run
        """
        scheduled = ResultSet([])
        for o in objs:
            scheduled.add(fn.delay(frame, o))
        return scheduled

    def worker_x_iterator(self, scheduled):
        """
        Loop through the scheduled worker tasks.  This will block until each consecutive task is ready
        Creates the iterator that returns a single feature or result per iteration 
        (even if the inspection/measurement returned a list, this breaks it up)
        """
        for output in scheduled:
            for out in output:
                # de-serialized json features/results do not get their _changed_fields set correctly
                # so manually do it to make sure mongoengine knows to properly save it
                for key in out._data.keys():
                    out._changed_fields.append(key)
                yield out

    def worker_inspection_iterator(self, frame, insps):
        # Calls the above worker_x_scheduler and iterator specifically for inspection execution
        # Combined the scheduling and retrieval of results for simplicity
        sched = self.worker_x_schedule(frame, insps, self.inspection_execute)
        return self.worker_x_iterator(sched)
        
    def worker_measurement_iterator(self, frame, meass):
        # Calls the above worker_x_scheduler and iteratorspecifically for measurement execution
        # Combined the scheduling and retrieval of results for simplicity
        sched = self.worker_x_schedule(frame, meass, self.measurement_execute)
        return self.worker_x_iterator(sched)
            
    def serial_inspection_iterator(self, frame, insps):
        """
        Make the API for a serial inspection work just like a worker inspection, so create an iterator for the features
        """
        for i in insps:
            try:
                features = i.execute(frame)
            except:
                features = []
            for feat in features:
                yield feat
                
    def serial_measurement_iterator(self, frame, meass):
        """
        Make the API for serial measurement work just like a worker measurement, so create an iterator for the results
        """
        for m in meass:
            results = m.execute(frame)
            
            for res in results:
                for key in res._data.keys():
                    res._changed_fields.append(key)
                yield res

    @task
    def inspection_execute(frame, inspection):
        """ 
        This is the function that is run inside the worker to perform inspection.execute
        """
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
        """
        This is the function that is run inside the worker to perform measurement.execute
        """
        try:
            log.warn('{} Measuring {}'.format(measurement.id, frame.id))
            results = measurement.execute(frame)
            return results        
        except Exception as e:
            log.error(e)
            return []
            
