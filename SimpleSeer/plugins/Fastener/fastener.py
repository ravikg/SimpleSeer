import numpy as np

from SimpleCV import *
from SimpleSeer import models as M
from SimpleSeer import util

from SimpleSeer.plugins import base
"""
Overly simplified template matching plugin

insp = Inspection( name= "SimpleTemplate", 
                   method="simpleTemplate", 
                   camera = "Default Camera")
insp.save()

#Inspection(name="derp7",method="simpleTemplate",parameters={"template":"/home/kscottz/SimpleSeer/SimpleSeer/plugins/SimpleTemplate/template.png"}).save()


"""

class FastenerFeature(SimpleCV.Feature):

  def __init__(self,head,shaft,lbs,fillet,top,bottom,bb,img,dpi=1200):
    self.dpi = dpi

    self.head_left = head[0]
    self.head_right = head[1] 
    self.head_width = 0

    self.shaft_left = shaft[0]
    self.shaft_right = shaft[1] 
    self.shaft_width = 0

    self.lbs_left = lbs[0]
    self.lbs_right = lbs[1] 
    self.lbs_angle = 0

    self.fillet_left = fillet[0]
    self.fillet_right = fillet[1] 
    
    at_x = bb[0] + bb[2]/2
    at_y = bb[1] + bb[3]/2 
    width = bb[2]
    height = bb[3]
    points = ((x, y), (x + width, y), (x + width, y + height), (x, y + height))
    super(FastenerFeature, self).__init__(i, at_x, at_y, points)             


class Fastener(base.InspectionPlugin):
  """
  Fastner
  """
  def clipAndRecenter(toClip,a,b,img,mode="horizontal"):
    """
    clip and recenter toClip to fit and be centered between a and b
    mode is the direction of the toclip
    """
    if( mode == "vertical" ):
      pass
    else:
      l = abs(a.x-b.x)
      mp = (a.x+b.x)/2
      if(toClip.length() < l ):
        l = int(toClip.length())
        y = toClip.y
        retVal = Line(img,((mp-(l/2),y),(mp+(l/2),y)))
        
    return retVal

  def __call__(self, image):
    params = util.utf8convert(self.inspection.parameters)
    retVal = []
    
    result = image
    #flood fill ro remove noise
    result = result.floodFill(np.array([(20,20)]),20,color=Color.BLACK)

    binary = result.threshold(20).dilate(1)
    l = binary.findLines(threshold=10,minlinelength=15 )#,cannyth1=40,cannyth2=120,maxlinegap=2)
    b = result.findBlobsFromMask(mask=binary)
    l = l.reassignImage(result)

    # set some parameters 
    bolt_x = b[-1].x
    bolt_y = b[-1].y
    top_x = b[-1].topLeftCorner()[0]
    top_y = b[-1].topLeftCorner()[1]
    bolt_width = b[-1].width()
    bolt_height = b[-1].height()
    bh4 = bolt_height/4
    bw4 = bolt_width/4
    sx = 100
    sy = 20
    c = Color.ORANGE
    #filter out the lines 
    v = 80
    vertical = FeatureSet([i for i in l if (i.angle() > v) or (i.angle() < -1*v)])

    h = 5
    horizontal = FeatureSet([i for i in l if (i.angle() < h) and (i.angle() > -1*h)])

    top = getLongestInROI(horizontal,(0,top_y,result.width,bolt_height/4), result, mode="horizontal")
    bottom = getLongestInROI(horizontal,(0,top_y+(3*bh4),result.width,bolt_height/4), result, mode="horizontal")
    #LOAD BEARING SURFACES
    lbs_left = getLongestInROI(horizontal,(0,bolt_y-bh4,result.width/2,bolt_height/2), result, mode="horizontal")
    lbs_right = getLongestInROI(horizontal,(bolt_x,bolt_y-bh4,result.width/2,bolt_height/2), result, mode="horizontal")

    #FROM the load bearing surfaces find the best postion 
    yavg = bolt_y+(2*bh4)
    if( lbs_left is not None and lbs_right is not None ):
        ys = [lbs_left.end_points[0][1],
              lbs_left.end_points[0][1],
              lbs_right.end_points[1][1],
              lbs_right.end_points[1][1] ]

        xs = [lbs_left.end_points[0][0],
              lbs_left.end_points[0][0],
              lbs_right.end_points[1][0],
              lbs_right.end_points[1][0] ]
        minx = np.min(xs)
        maxx = np.max(xs)
        yavg = np.average(ys)
        result.drawLine((minx, yavg), (maxx, yavg), color=Color.VIOLET, thickness=1)
    elif( lbs_left is not None ):
        minx = np.min([lbs_left.end_points[0][0],lbs_left.end_points[1][0]])
        maxx = np.max([lbs_left.end_points[0][0],lbs_left.end_points[1][0]])
        yavg = np.average([lbs_left.end_points[0][1],lbs_left.end_points[1][1]])
    elif( lbs_left is not None ):
        minx = np.min([lbs_right.end_points[0][0],lbs_right.end_points[1][0]])
        maxx = np.max([lbs_right.end_points[0][0],lbs_right.end_points[1][0]])
        yavg = np.average([lbs_right.end_points[0][1],lbs_right.end_points[1][1]])
    else:
        warnings.warn("COULD NOT FIND BOLT HEAD")

    # use the load bearing surfaces to segment out the head and shaft
    shaft_left = getLongestInROI(vertical,(0,yavg,result.width/2,bolt_y+bolt_height-yavg), result, mode="vertical")
    shaft_right = getLongestInROI(vertical,(result.width/2,yavg,result.width/2,bolt_y+bolt_height-yavg), result, mode="vertical")
    head_left = getLongestInROI(vertical,(top_x,0,bolt_width/2,0.8*yavg), result, mode="vertical")
    head_right = getLongestInROI(vertical,(top_x+(bolt_width/2),0,(bolt_width/2),0.8*yavg), result, mode="vertical")

    # now render
    if( bottom is not None):
        if( shaft_left is not None and
            shaft_right is not None ):
            bottom = self.clipAndRecenter(bottom,shaft_left,shaft_right,result,"")

    if( top is not None):
        if( head_left is not None and
            head_right is not None ):
            top = self.clipAndRecenter(top,head_left,head_right,result,"")

    ff = M.FrameFeature()
    head = (head_left, head_right)
    shaft = (shaft_left, shaft_right)
    lbs = (lbs_left, lbs_right)
    fillet = ((shaft_left.x,lbs_left.y),(shaft_right.x,lbs_right.y))
    bb = (top_x,top_y,bolt_width,bolt_height)

    feature = FastnerFeature(head,shaft,lbs,fillet,top,bottom,bb,result):
    ff.setFeature(feature)
    retVal.append(ff)

    if( params.has_key("saveFile") ):
      result.drawLine((bolt_x-sx, bolt_y-bh4), (bolt_x+sx, bolt_y-bh4), color=c, thickness=1)
      result.drawLine((bolt_x, bolt_y-sy-bh4), (bolt_x, bolt_y+sy-bh4), color=c, thickness=1)
      result.drawLine((bolt_x-sx, bolt_y+bh4), (bolt_x+sx, bolt_y+bh4), color=c, thickness=1)
      result.drawLine((bolt_x, bolt_y-sy+bh4), (bolt_x, bolt_y+sy+bh4), color=c, thickness=1)
      result.drawLine((bolt_x-sx, bolt_y), (bolt_x+sx, bolt_y), color=c, thickness=1)
      result.drawLine((bolt_x, bolt_y-sy), (bolt_x, bolt_y+sy), color=c, thickness=1)
      if( top is not None):        
        top.draw(color=Color.WHITE,width=3)

      if( bottom is not None):
        bottom.draw(color=Color.WHITE,width=3)
      
      if( shaft_left is not None):
        shaft_left.draw(color=Color.BLUE,width=3)
      
      if( shaft_right is not None):
        shaft_right.draw(color=Color.BLUE,width=3)

      if( head_left is not None):
        head_left.draw(color=Color.YELLOW,width=3)

      if( head_right is not None):
        head_right.draw(color=Color.YELLOW,width=3)

      if( lbs_left is not None):
        lbs_left.draw(color=Color.HOTPINK,width=3)

      if( lbs_right is not None):
        lbs_right.draw(color=Color.HOTPINK,width=3)

      sz = 80

      if( lbs_left is not None and shaft_left is not None ):
        result.drawCircle((shaft_left.x,lbs_left.y),40,color=Color.ORANGE,thickness=3)
        
      if( lbs_right is not None and shaft_right is not None ):
        result.drawCircle((shaft_right.x,lbs_right.y),40,color=Color.ORANGE,thickness=3)

      result.save(params["saveFile"])

    return retVal 

