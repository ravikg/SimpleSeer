import pymongo
from collections import defaultdict

from . import Frame, Measurement

class Foreman():
    
    _db = None
    
    def __init__(self):
        self._db = Frame._get_db()
        
    def enqueue(self, measurement_id):
        for f in Frame.objects:
            # Add the measurement to the frame/measurement grid.  Create the entry if it does not exist
            self._db.foreman.update({'frame_id': f.id}, {'$push': {'measurements': measurement_id}}, True)
    
    def run(self):
        
        res = self._db.foreman.find_and_modify({}, remove=True)
        while res:
            f = Frame.objects.get(id=res['frame_id'])
            
            for m_id in res['measurements']:
                m = Measurement.objects.get(id=m_id)
                m.execute(f, f.features)
            
            f.save()
            res = self._db.foreman.find_and_modify({}, remove=True)
        
