import numpy as np

import SimpleCV
from SimpleSeer import models as M
from SimpleSeer import util

from SimpleSeer.plugins import base

"""
Overly simplified motion detection plugin
insp = Inspection( name= "EdgeWidth", method="edgeWidth", camera = "Default Camera")
insp.save()

meas = Measurement( name="movement", label="Movement", method = "movement", parameters = dict(), units = "", featurecriteria = dict( index = 0 ), inspection = insp.id )
meas.save()


"""

class EdgeWidthFeature(SimpleCV.Line):
  distance = 0 #the distance between the two intersection points
  intersectionPts = [] # the two points of intersection
  sourceLinePts = [] # the two points that define the line where we look for intersections

  def __init__(self, image, srcPts,intersections ):
    #TODO, if parameters are given, crop on both images
    self.image = image
    self.end_points = intersections
    self.sourceLinePts = srcPts 
    line = intersections 
    at_x = (line[0][0] + line[1][0]) / 2
    at_y = (line[0][1] + line[1][1]) / 2
    xmin = np.min([line[0][0],line[1][0]])
    xmax = np.max([line[0][0],line[1][0]])
    ymax = np.min([line[0][1],line[1][1]])
    ymin = np.max([line[0][1],line[1][1]])
    points = [(xmin,ymin),(xmin,ymax),(xmax,ymax),(xmax,ymin)]
    super(Line, self).__init__(i, at_x, at_y,points)
    
class EdgeWidth(base.InspectionPlugin):

  def __call__(self, image):
    pt0 = None
    pt1 = None 
    canny1 = 0
    canny2 = 100 
    width = 3

    params = util.utf8convert(self.inspection.parameters)    

    if( params.has_key("pt0")):
      pt0 = params["pt0"]
    else: # required
      return []

    if( params.has_key("pt1")):
      pt1 = params["pt1"]
    else: # required
      return []

    if( params.has_key("canny2")):
      canny2 = params["canny2"]
      
    if( params.has_key("canny1")):
      canny1 = params["canny1"]

    if( params.has_key("width")):
      width = params["width"]
  
    result = image.edgeIntersections(pt0,pt1,width,canny1,canny2)
    
    retVal = []
    if(result[0] is not None and
       result[1] is not None ):
      ff = M.FrameFeature()
      ewf = EdgeWidthFeature(image,[pt0,pt1],result)
      ff.setFeature(ewf)
      retVal.append(ff)
      
    return retVal
