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
log = logging.getLogger()

from . import celeryconfig
celery = Celery()
celery.config_from_object(celeryconfig)
            
ensure_plugins()
            

def nextInInterval(frame, field, interval):
    currentValue = 0
    try:
        currentValue = getattr(frame, field)
    except:
        currentValue = frame.metadata[field]
        field = 'metadata__' + field
    
    roundValue = currentValue - (currentValue % interval)
    kwargs = {'%s__gte' % field: roundValue, '%s__lt' % field: currentValue, 'camera': frame.camera}
    if M.Frame.objects(**kwargs).count() == 0:
        return True
    return False

class Foreman():
# Manages a lot of worker-related tasks
# This is a borg (speed worker status, plugin checks)

    _useWorkers = False
    _initialized = False
    
    __sharedState = {}
    
    def __init__(self):
        self.__dict__ = self.__sharedState
            
        if not self._initialized:
            self._useWorkers = self.workerRunning()
            self._initialized = True
            ensure_plugins()

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
        # Need to test the next in interval... used by scanline measurement in zingermans
        measKwargs = {}
        
        if frame.features:        
            # only measurements for which there is a matching feature...
            # exact format of feature object depends on whether it came from worker or serial
            if '_data' in frame.features[0]:
                insps = [ feat.inspection for feat in frame.features ]
            else:
                insps = [ feat.__dict__['inspection'] for feat in frame.features ]
            measKwargs['inspection__in'] = insps
            
            if measurements:
                measKwargs['id__in'] = measurements
            
            filteredMeass = M.Measurement.objects(**measKwargs)
            
            if self._useWorkers:
                return self.worker_measurement_iterator(frame, filteredMeass)
            else:
                return self.serial_measurement_iterator(frame, filteredMeass)

    def worker_inspection_iterator(self, frame, insps):
        return self.worker_x_iterator(frame, insps, self.inspection_execute)
        
    def worker_measurement_iterator(self, frame, meass):
        return self.worker_x_iterator(frame, meass, self.measurement_execute)
            
    def worker_x_iterator(self, frame, objs, fn):
        from time import sleep
        
        scheduled = []
        for o in objs:
            scheduled.append(fn.delay(frame.id, o.id))
        
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
        try:
            frame = M.Frame.objects.get(id=fid)
            inspection = M.Inspection.objects.get(id=iid)
            features = inspection.execute(frame)
            return features        
        except Exception as e:
            log.info(e)
            print e

    @task
    def measurement_execute(fid, mid):
        try:
            frame = M.Frame.objects.get(id=fid)
            measurement = M.Measurement.objects.get(id=mid)
            results = measurement.execute(frame)
            return results        
        except Exception as e:
            log.info(e)
            print e
