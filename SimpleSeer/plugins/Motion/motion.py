import numpy as np

import SimpleCV
from SimpleSeer import models as M
from SimpleSeer import util

from SimpleSeer.plugins import base

"""
Overly simplified motion detection plugin
insp = Inspection( name= "Motion", method="motion", camera = "Default Camera")
insp.save()

meas = Measurement( name="movement", label="Movement", method = "movement", parameters = dict(), units = "", featurecriteria = dict( index = 0 ), inspection = insp.id )
meas.save()


"""

class MotionTrend(base.MeasurementPlugin):
    
    def __call__(self, frame, featureset):
        meas = self.measurement
        timeframe = meas.parameters.get("timeframe", 0)
        motionthreshhold = meas.parameters.get("motionthreshhold", 0)
        
        frameset = Frame.objects(capturetime__gt = frame.capturetime - timedelta(0, timewindow),
           capturetime__lt = frame.capturetime, 
           camera = frame.camera
           ).order_by("capturetime")
        if len(frameset) < minframes:
            return []
        
        frameset = list(frameset) #load into memory




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
        frames = M.Frame.objects(camera = self.inspection.camera).order_by('-capturetime')
    else:
        frames = M.Frame.objects.order_by('-capturetime')
    
    if frames.count() > 1:
      lastframe = frames[1]
      lastimage = lastframe.image
    else:
      return None

    diff = (image - lastimage) + (lastimage - image)

    fid = None
    if hasattr(lastframe, "_id"):
      fid = lastframe._id
    return [MotionFeature(image, np.mean(diff.meanColor()), fid)]
