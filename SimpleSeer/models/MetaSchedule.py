import pymongo
from collections import defaultdict

from . import Frame, Measurement
from ..worker import backfill_tolerances

class Foreman():
    
    _db = None
    
    def __init__(self):
        self._db = Frame._get_db()
        
    def enqueue_measurement(self, measurement_id):
        for f in Frame.objects:
            # Add the measurement to the frame/measurement grid.  Create the entry if it does not exist
            self._db.foreman.update({'frame_id': f.id}, {'$push': {'measurements': measurement_id}}, True)
    
    def enqueue_inspection(self, inspection_id):
        for f in Frame.objects:
            self._db.foreman.update({'frame_id': f.id}, {'$push': {'inspections': inspection_id}}, True)
    
    def run(self):
        
        res = self._db.foreman.find_and_modify({}, remove=True)
        while res:
            f = Frame.objects.get(res['frame_id'])
            f.results = backfill_tolerances.delay(res['measurements'], f.id)
            f.save()
            
            res = self._db.foreman.find_and_modify({}, remove=True)
        
