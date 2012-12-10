import pymongo
from collections import defaultdict

from . import Frame, Measurement
from ..worker import backfill_tolerances

class MetaSchedule():
    
    _db = None
    _parallel_tasks = 10
    
    def __init__(self):
        self._db = Frame._get_db()
        self._db.metaschedule.ensure_index('frame_id')
        self._db.metaschedule.ensure_index('semaphore')
        
        
    def enqueue_measurement(self, measurement_id):
        to_add = []
        for f in Frame.objects:
            # Add the measurement to the frame/measurement grid.  Create the entry if it does not exist
            to_add.append({'frame_id': f.id, 'measurement_id': measurement_id})
        
        to_check = to_add.pop()
        while to_check:
            # make sure the current entry is not locked:
            if self._db.metaschedule.find({'frame_id': to_check['frame_id'], 'semaphore': 1}).count() == 0:
                self._db.metaschedule.update({'frame_id': to_check['frame_id'], 'semaphore': 0}, {'$push': {'measurements': to_check['measurement_id']}}, True)
            else:
                # otherwise, put it back
                to_add.push(to_check)
                
            if to_add:
                to_check = to_add.pop()
            else:
                to_check = None
    
    def enqueue_inspection(self, inspection_id):
        for f in Frame.objects:
            self._db.metaschedule.update({'frame_id': f.id, 'semaphore': 0}, {'$push': {'inspections': inspection_id}}, True)
    
    def run(self):
        from time import sleep
        from . import ResultEmbed
        
        scheduled = []
        while self._db.metaschedule.find().count() > 0 or len(scheduled) > 0:
            
            # If I'm ready to schedule another task and there are tasks to schedule
            print self._db.metaschedule.find().count()
            if len(scheduled) < self._parallel_tasks and self._db.metaschedule.find({'semaphore': 0}).count() > 0:
                # Update the semaphore field to lock other frames with the same id from running
                meta = self._db.metaschedule.find_and_modify(query = {'semaphore': 0}, update = {'$inc': {'semaphore': 1}})
                if meta:
                    print 'scheduling %s' % meta['frame_id']
                    scheduled.append(backfill_tolerances.delay(meta['measurements'], meta['frame_id']))
            else:
                # wait for the queue to clear a bit
                print 'sleepy time'
                sleep(0.2)
            
            complete_indexes = []
            if len(scheduled) > 0:
                for index, s in enumerate(scheduled):
                    if s.ready():
                        # Note, want index in reverse order so can pop withouth changes indexes later
                        complete_indexes.insert(0,index)
            
            for index in complete_indexes:
                async = scheduled.pop(index)
                frame_id, results = async.get()
                print 'should save %s' % frame_id
                
                # Save the new computations to the db
                f = Frame.objects.get(id=frame_id)
                # The ResultEmbed object gets mangled, so reconstruct it
                
                f.results = []
                for r in results:
                    re = ResultEmbed()
                    re._data.update(r.__dict__)
                    f.results.append(re)
                f.save()
                
                # Clear the entry from the queue
                print self._db.metaschedule.find_and_modify({'frame_id': frame_id, 'semaphore': 1}, {}, remove=True)
