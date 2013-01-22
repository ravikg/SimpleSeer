from .Frame import Frame
from .Inspection import Inspection

from formencode import validators as fev
from formencode import schema as fes
import formencode as fe

class FrameSetSchema(fes.Schema):
    name = fev.UnicodeString(not_empty=True)
    frames = fe.ForEach(fev.UnicodeString(), convert_to_list=True)    

class FrameSet():
    _metadata = {}
    _frames = []
    _reqInspections = []

    def __init__(self, reqInspections = [], metadata = {}):
        self._metadata = metadata
        self._frames = []
        
        for req in reqInspections:
            self._reqInspections.append(Inspection.objects.get(name=req).id)
        
    def load(self):
        criteria = {}
        for k, v, in self._metadata.items():
            criteria['metadata__' + k] = v
            
        _frames = Frame.objects(**criteria) 
    
    def add(self, frame):
        if self._metadata:
            frame.metadata = self._metadata
        
        # Do not add if frame by camera already present
        alreadyInSet = False
        for f in self._frames:
            if f.camera == frame.camera:
                alreadyInSet = True
                
        if not alreadyInSet:
            self._frames.append(frame)
        
    def complete(self):
        for i in self._reqInspections:
            passed = False
            for f in self._frames:
                for feat in f.features:
                    if feat.inspection == i:
                        passed = True
            
            if passed == False:
                return False
        
        return True
        
    def save(self):
        for f in self._frames:
            f.skipOLAP = True
            f.save()
        
    def __repr__(self):
        return "[FrameSet %s ]" % self._metadata
