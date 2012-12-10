import pymongo
from collections import defaultdict

from . import Frame, Measurement
from ..worker import backfill_tolerances

class MetaSchedule():
    
    _db = None
    _parallel_tasks = 10
    
    def __init__(self):
        self._db = Frame._get_db()
        
    def enqueue_measurement(self, measurement_id):
        for f in Frame.objects:
            # Add the measurement to the frame/measurement grid.  Create the entry if it does not exist
            self._db.metaschedule.update({'_id': f.id, 'semaphore': 0}, {'$push': {'measurements': measurement_id}}, True)
    
    def enqueue_inspection(self, inspection_id):
        for f in Frame.objects:
            self._db.metaschedule.update({'_id': f.id, 'semaphore': 0}, {'$push': {'inspections': inspection_id}}, True)
    
    def run(self):
        from time import sleep
        from . import ResultEmbed
        
        scheduled = []
        while self._db.metaschedule.find().count() > 0 or len(scheduled) > 0:
            
            # If I'm ready to schedule another task and there are tasks to schedule
            print self._db.metaschedule.find().count()
            if len(scheduled) < self._parallel_tasks and self._db.metaschedule.find({'semaphore': 0}).count() > 0:
                # TODO: Make sure entry with same frame id is not running
                
                # Update the semaphore field to lock other frames with the same id from running
                meta = self._db.metaschedule.find_and_modify(query = {'semaphore': 0}, update = {'semaphore': 1})
                print 'scheduling %s' % meta['_id']
                scheduled.append(backfill_tolerances.delay(meta['measurements'], meta['_id']))
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
                print self._db.metaschedule.find_and_modify({'_id': frame_id, 'semaphore': 1}, {}, remove=True)
