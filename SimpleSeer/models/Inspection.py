from copy import deepcopy

import mongoengine
from mongoengine import signals as sig

from formencode import validators as fev
from formencode import schema as fes
import formencode as fe

from SimpleSeer import validators as V
from SimpleSeer import util

from datetime import datetime

from .base import SimpleDoc, WithPlugins
from .Measurement import Measurement
from .FrameFeature import FrameFeature
from .Frame import Frame

import logging
log = logging.getLogger()

class InspectionSchema(fes.Schema):
    parent = V.ObjectId(if_empty=None, if_missing=None)
    name = fev.UnicodeString(not_empty=True)
    method = fev.UnicodeString(not_empty=True)
    camera = fev.UnicodeString(if_empty="")
    parameters = V.JSON(if_empty=dict, if_missing=None)
    filters = V.JSON(if_empty=dict, if_missing=None)
    richattributes = V.JSON(if_empty=dict, if_missing=None)
    morphs = fe.ForEach(fev.UnicodeString(), convert_to_list=True)


class Inspection(SimpleDoc, WithPlugins, mongoengine.Document):
    """
    
    An Inspection determines what part of an image to look at from a given camera
    and what Measurement objects get taken.  It has a single handler, the method,
    which determines ROI for the measurements.
    
    The method determines if measurements are or are not taken.  A completely
    passive method would return the entire image space (taking measurements
    on every frame), and an "enabled = 0" equivalent would be method always
    returning None.
    
    The method can return several samples, pieces of the evaluated frame,
    and these get passed in turn to each Measurement.
    
    The results from these measurements are aggregated and returned from the
    Inspection.execute() function, which gives all samples to each measurement.
    
    insp = Inspection(
        name = "Area of Interest",
        method = "region",
        camera = "Default Camera",
        parameters = dict( x =  100, y = 100, w = 400, h = 300)) #x,y,w,h

    insp.save()
    
    Measurement(..., inspection_id = insp.id )
    
    results = insp.execute()       
    
    """
    name = mongoengine.StringField(default='')
    parent = mongoengine.ObjectIdField(default=None)
    
    method = mongoengine.StringField(default='')
    #TODO, validate that this method exists
    camera = mongoengine.StringField(default='')
    #TODO validate that this camera exists
    # use (int) parameters['interval'] to run Inspection every N seconds
    parameters = mongoengine.DictField(default={})
    #TODO validate against function
    filters = mongoengine.DictField(default={})
    #TODO validate against valid fields for the feature type
    richattributes = mongoengine.DictField(default={})
    #TODO validate against attributes
    morphs = mongoengine.ListField(default=[])
    #list of dicts for morph operations
    #TODO validate agains morph operations
    updatetime = mongoengine.DateTimeField(default=None)

    meta = {
        'indexes': ['name']
    }

    def __init__(self):
        from .base import checkPreSignal, checkPostSignal
        from SimpleSeer.Session import Session
        
        super(Inspection, self).__init__()
        
        app = Session._Session__shared_state['appname']
        
        for pre in checkPreSignal('Inspection', app):
            sig.pre_save.connect(pre, sender=Frame, weak=False)
        
        for post in checkPostSignal('Inspection', app):
            sig.post_save.connect(post, sender=Frame, weak=False)


    def __repr__(self):
      return "<%s: %s>" % (self.__class__.__name__, self.name)
                    
    def execute(self, frame, parents = {}):
        """
        The execute method takes in a frame object, executes the method
        and sends the samples to each measurement object.  The results are returned
        as a multidimensional array [ samples ][ measurements ] = result
        """
        
        # For legacy testing, make sure we have a frame and not an image
        if not type(frame) == Frame:
            log.warn('inspection execute not expects a frame instead of an image')
            return []
        
        # Pull the frame metadata into the inspection's metadata
        
        self.parameters['metadata'] = frame.metadata
        #execute the morphs?
        
        #recursion stopper so we don't accidentally end up in any loops
        if parents.has_key(self.id):
            return []
        
        method_ref = self.get_plugin(self.method)
        #get the ROI function that we want
        #note that we should validate/roi method
        
        startexectime = datetime.now()
        featureset = method_ref(frame.image)
        execdelta = datetime.now() - startexectime
        
        exectime = float(execdelta.seconds) + execdelta.microseconds / 1000000.0
        
        if not featureset:
            return []
    
        frameFeatSet = []
        if type(featureset[0]) == FrameFeature:
            log.warn('Plugins should return SimpleCV Features.')
            frameFeatSet = featureset
        else:
            for feat in featureset:
                ff = FrameFeature()
                ff.setFeature(feat)
                ff.exectime = exectime
                frameFeatSet.append(ff)
    
        if "skip" in self.parameters or "limit" in self.parameters:
            frameFeatSet = frameFeatSet[self.parameters.get("skip",None):self.parameters.get("limit",None)]
        
        #we're executing an unsaved inspection, which can have no children
        if not self.id:
            return frameFeatSet
        
        for r in frameFeatSet:
            r.inspection = self.id
        
        children = self.children
        
        if not children:
            return frameFeatSet
        
        if children:
            newparents = deepcopy(parents)
            newparents[self.id] = True
            for r in frameFeatSet:
                f = r.feature
                f.image = frame.image
                roi = f.crop()
            
                for child in children:    
                    r.children.extend(child.execute(roi, newparents))
                
        return frameFeatSet

    def save(self, *args, **kwargs):
        from ..realtime import ChannelManager
        
        self.updatetime = datetime.utcnow()
        
        # Ensure name is unique
        for i in Inspection.objects:
            if i.name == self.name and i.id != self.id:
                log.info('trying to save inspections with duplicate names: %s' % i.name)
                if self.name[-1].isdigit():
                    self.name = self.name[:-1] + str(int(self.name[-1]) + 1)
                else:
                    self.name = self.name + '_1'
        
        super(Inspection, self).save(*args, **kwargs)
        ChannelManager().publish('meta/', self)
            
    @property
    def children(self):
        return Inspection.objects(parent = self.id)
        
    @property
    def measurements(self):
        return Measurement.objects(inspection = self.id)
        
    @property
    def featureclass(self):
        return self.get_plugin(self.method).featureclass
        
    def __eq__(self, other):
        if isinstance(other, self.__class__):
            # Note: ignoring name to test if this inspection is functionally equivalent to other inspection (name is irrelevant)
            banlist = [None, 'updatetime', 'name']
            params = [ a for a in self.__dict__['_data'] if not a in banlist ]
            
            for p in params:
                if self.__getattribute__(p) != other.__getattribute__(p):
                    return False
            return True
        else:
            return False    

