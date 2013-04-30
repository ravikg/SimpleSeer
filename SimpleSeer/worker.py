from .Session import Session
from celery import Celery
from celery import task
from celery.exceptions import RetryTaskError
from celery.contrib import rdb

from bson import ObjectId
from gridfs import GridFS

from .util import ensure_plugins, jsonencode

from .realtime import ChannelManager
from . import models as M

import logging
from celery.utils import log
log = log.get_task_logger(__name__)

from . import celeryconfig
celery = Celery()
celery.config_from_object(celeryconfig)
            
ensure_plugins()
            
class InspectionLogHandler(logging.Handler):
    
    _inspection = None
    
    def __init__(self, inspection):
        self._inspection = inspection
        print 'log {}'.format(inspection)
        
    def emit(self, msg):
        print 'I like errors'

class Foreman():
# Manages a lot of worker-related tasks
# This is a borg (speed worker status, plugin checks)

    _useWorkers = False
    _initialized = False
    _log = {}
    
    __sharedState = {}
    
    def __init__(self):
        from .realtime import PubSubHandler
            
        self.__dict__ = self.__sharedState
            
        if not self._initialized:
            self._useWorkers = self.workerRunning()
            self._initialized = True
            ensure_plugins()
            
            # Have to do some extra log handling simple celery doesn't play well with other loggers
            mainLogger = logging.getLogger(__name__)
            
            log.addHandler(PubSubHandler())
            log.setLevel(mainLogger.getEffectiveLevel()) 

    def workerRunning(self):
        i = celery.control.inspect()
        if i.active_queues() is not None:
            return True
        else:
            return False

    def process_inspections(self, frame, inspections=None):
        inspKwargs = {'camera': frame.camera, 'parent__exists': False}
        if inspections:
            inspKwargs['id__in'] = inspections
        
        filteredInsps = M.Inspection.objects(**inspKwargs)
        
        if self._useWorkers:
            return self.worker_inspection_iterator(frame, filteredInsps)    
        else:
            return self.serial_inspection_iterator(frame, filteredInsps)

    def process_measurements(self, frame, measurements=None):
        measKwargs = {}
        
        if frame.features:        
            # only measurements for which there is a matching feature...
            # exact format of feature object depends on whether it came from worker or serial
            if '_data' in frame.features[0]:
                insps = [ feat.inspection for feat in frame.features ]
            else:
                insps = [ feat.__dict__['inspection'] for feat in frame.features ]
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
        return self.worker_x_iterator(frame, insps, sched)
        
    def worker_measurement_iterator(self, frame, meass):
        sched = self.worker_x_schedule(frame, meass, self.measurement_execute)
        return self.worker_x_iterator(frame, meass, sched)
            
    def worker_x_schedule(self, frame, objs, fn):
        scheduled = []
        for o in objs:
            print 'Scheduling {}'.format(o)
            scheduled.append(fn.delay(frame.id, o.id))
        return scheduled
            
    def worker_x_iterator(self, frame, objs, scheduled):
        from time import sleep
        print 'iter'
        
        completed = 0
        while completed < len(objs):
            ready = []
            
            # List of scheduled items ready
            for idx, s in enumerate(scheduled):
                if s.ready():
                    ready.insert(0, idx)
                    
            # Get the completed results
            for idx in ready:
                async = scheduled.pop(idx)
                output = async.get()
                for out in output:
                    yield out
                completed += 1
            
            sleep(0.1)

    def serial_inspection_iterator(self, frame, insps):
        for i in insps:
            features = i.execute(frame)
            for feat in features:
                yield feat
                
    def serial_measurement_iterator(self, frame, meass):
        for m in meass:
            results = m.execute(frame)
            for res in results:
                yield res

    @task
    def inspection_execute(fid, iid):
        log.addHandler(InspectionLogHandler(iid))
        try:
            print(repr(self.log.handlers))
            log.warn('Inspecting {}'.format(iid))
            frame = M.Frame.objects.get(id=fid)
            inspection = M.Inspection.objects.get(id=iid)
            features = inspection.execute(frame)
            return features        
        except Exception as e:
            log.error(e)
            print error
            return []

    @task
    def measurement_execute(fid, mid):
        try:
            log.info('Measuring {}'.format(mid))
            frame = M.Frame.objects.get(id=fid)
            measurement = M.Measurement.objects.get(id=mid)
            results = measurement.execute(frame)
            return results        
        except Exception as e:
            log.error(e)
