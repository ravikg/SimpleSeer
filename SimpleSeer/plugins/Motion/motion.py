import numpy as np

import SimpleCV
from SimpleSeer import models as M
from SimpleSeer import util
from SimpleSeer.models import Frame
from datetime import timedelta

from SimpleSeer.plugins import base

"""
Overly simplified motion detection plugin
insp = Inspection( name= "Motion", method="motion", camera = "Default Camera")
insp.save()

meas = Measurement( name="movement", label="Movement", method = "movement", parameters = dict(), units = "", featurecriteria = dict( index = 0 ), inspection = insp.id )
meas.save()


"""

"""
Counts frames with motion less than threshold in latest valley.
ie:  in the following frames separated by threshold, the plugin would return 4

    +-------+  +----+
    |       |  |    |
----+       +--+    -----

"""

class MotionTrend(base.MeasurementPlugin):
    
    def __call__(self, frame, featureset):
        meas = self.measurement
        minframes = 2
        timewindow = meas.parameters.get("timewindow", 60)
        motionthreshhold = meas.parameters.get("motionthreshhold", 5)
        trend = [0]
        
        lastmotion = [feature for feature in frame.features if feature.featuretype == "MotionFeature"]
        
        #import pdb; pdb.set_trace();
        if not len(lastmotion):
            return []
        
        feature = lastmotion[0]
        if feature.featuretype == "MotionFeature" and feature.feature.movement > motionthreshhold:
            return trend
            
        frameset = Frame.objects(capturetime__gt = frame.capturetime - timedelta(seconds=timewindow),
           capturetime__lt = frame.capturetime, 
           camera = frame.camera
           ).order_by("capturetime")
        if len(frameset) < minframes:
            return trend
        #print len(frameset)
        frameset = reversed(frameset) #load into memory
        
        for frame in frameset:
            motion = [feature for feature in frame.features if feature.featuretype == "MotionFeature"]
            
            if len(motion) and motion[0].feature.movement < motionthreshhold:
                #print motion[0].feature.movement, motionthreshhold
                trend[0]+=1
            else:
                break
        return trend
            




class MotionFeature(SimpleCV.Feature):
  movement = 0.0

  def __init__(self, image, mval, compared_with=None, top = 0, left = 0, right = -1, bottom = -1):
    #TODO, if parameters are given, crop on both images    

    self.image = image
    self.movement = mval
    self.compared = compared_with

    if (right == -1):
      right = image.width

    if (bottom == -1):
      bottom = image.height

    self.points = [(left, top), (right, top), (right, bottom), (left, bottom)]
    self.x = left + self.width() / 2
    self.y = top + self.height() / 2

class Motion(base.InspectionPlugin):
  
  @classmethod
  def coffeescript(cls):
    yield "models/feature", '''
class MotionFeature
  constructor: (feature) ->
    @feature = feature
    
  represent: () =>
    Math.round(@feature.get("featuredata").movement) + "%" + " Motion Detected"
  
  icon: => "/img/motion.png"
  
  render: (pjs) =>
    return
plugin this, MotionFeature:MotionFeature
'''

  def __call__(self, image):
    if self.inspection.camera:
        frames = M.Frame.objects(camera = self.inspection.camera).order_by('-capturetime').limit(1)
    else:
        frames = M.Frame.objects.order_by('-capturetime').limit(1)
    
    if frames.count() > 0:
      lastframe = frames[0]
      lastimage = lastframe.image
    else:
      return None

    diff = (image - lastimage) + (lastimage - image)

    fid = None
    if hasattr(lastframe, "_id"):
      fid = lastframe._id
    return [MotionFeature(image, np.mean(diff.meanColor()), fid)]
