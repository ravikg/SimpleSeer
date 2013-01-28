from .Frame import Frame
from .Inspection import Inspection
from .FrameFeature import FrameFeature
from .Result import ResultEmbed

from formencode import validators as fev
from formencode import schema as fes
import formencode as fe

from .base import SimpleDoc, SONScrub
import mongoengine

from datetime import datetime
from calendar import timegm

import logging
log = logging.getLogger(__name__)


class FrameSetSchema(fes.Schema):
    name = fev.UnicodeString(not_empty=True)
    frames = fe.ForEach(fev.UnicodeString(), convert_to_list=True)    


class FrameSet(SimpleDoc, mongoengine.Document):
    
    _frames = []
    
    capturetime = mongoengine.DateTimeField()
    capturetime_epoch = mongoengine.IntField(default = 0)
    updatetime = mongoengine.DateTimeField()
    localtz = mongoengine.StringField(default='UTC')
    features = mongoengine.ListField(mongoengine.EmbeddedDocumentField(FrameFeature))
    results = mongoengine.ListField(mongoengine.EmbeddedDocumentField(ResultEmbed))
    metadata = mongoengine.DictField()
    frames = mongoengine.ListField()
    reqInspections = mongoengine.ListField()
    saveCams = mongoengine.ListField()

    meta = {
        'indexes': ["capturetime", "-capturetime", 
                    ("results.measurement_name", "results.numeric"),
                    ("results.measurement_name", "results.string"),
                    ("results.measurement_name", "results.state"),
                    "-capturetime_epoch", "capturetime_epoch", 
                    "results", 
                    "results.state", 
                    "metadata"]
    }

    def __init__(self, inspNames = [], metadata = {}, saveCams = [], *args, **kwargs):
        super(FrameSet, self).__init__(*args, **kwargs)
        
        try:
            self._frames = [ Frame.objects.get(id=fid) for fid in self.frames ]
        except:
            log.info('Error loading frame objects from ids')
        
        if metadata:
            self.metadata = metadata
        
        if saveCams:
            self.saveCams = saveCams
        
        self.capturetime = self.updatetime = datetime.utcnow()
        epoch_ms = timegm(self.capturetime.timetuple()) * 1000 + self.capturetime.microsecond / 1000
        self.capturetime_epoch = epoch_ms
        self.localtz = 'UTC'
        self.features = []
        self.results = []

        for req in inspNames:
            self.reqInspections.append(Inspection.objects.get(name=req).id)

        for fid in self.frames:
            self._frames.append(Frame.objects.get(id=fid))

    def add(self, frame):
        if self.metadata:
            frame.metadata = self.metadata
        
        # Do not add if frame by camera already present
        alreadyInSet = False
        for f in self._frames:
            if f.camera == frame.camera:
                alreadyInSet = True
                
        if not alreadyInSet:
            self._frames.append(frame)
        
    def complete(self):
        for i in self.reqInspections:
            passed = False
            for f in self._frames:
                for feat in f.features:
                    if feat.inspection == i:
                        passed = True
            
            if passed == False:
                return False
        
        return True
        
    def save(self, *args, **kwargs):
        for f in self._frames:
            if self.saveCams and not f.camera in self.saveCams:
                f.skipOLAP = True            
            f.save()
            self.frames.append(f.id)
            
            self.features += f.features
            self.results += f.results
        
        self.capturetime = self._frames[0].capturetime
        self.capturetime_epoch = self._frames[0].capturetime_epoch
        self.updatetime = datetime.utcnow()
        self.localtz = self._frames[0].localtz
        
        super(FrameSet, self).save(*args, **kwargs) 
        
            
    def __repr__(self):
        return "FrameSet of %s frames" % len(self.frames)


