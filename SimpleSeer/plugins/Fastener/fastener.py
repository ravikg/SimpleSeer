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
  def sanitizeNP64(self,derp):
    return ((float(derp[0][0]),float(derp[0][1])),(float(derp[1][0]),float(derp[1][1])))

  def angle_between(self,v1,v2):
    print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    print v1
    print v2
    x0 = (v1[0][0]-v1[1][0])
    y0 = (v1[0][1]-v1[1][1])
    mag0 = np.sqrt((x0*x0)+(y0*y0))
    print x0,y0,mag0

    x1 = (v2[0][0]-v2[1][0])
    y1 = (v2[0][1]-v2[1][1])
    mag1 = np.sqrt((x1*x1)+(y1*y1))
    print x1,y1,mag1

     
    dot = (x0*x1)+(y0*y1) / (mag0*mag1)
    print dot
    if( dot == 0 ):
      retVal = 90
    else:
      retVal = float((np.arccos([dot][0])*360.0)/(np.pi*2))
    return retVal

  def __init__(self,head,shaft,lbs,fillet,top,bottom,bb,img,dpi=1200):
    self.dpi = dpi
    #FML numpy.F64 sanitization
    print head[0]
    if( head[0] is not None):
      self.head_left = self.sanitizeNP64(head[0].end_points)
    else:
      print "FAIL"
      self.head_left = ((0,0),(1,1))

    if( head[1] is not None):
      self.head_right = self.sanitizeNP64(head[1].end_points)
    else:
      print "FAIL"
      self.head_right = ((0,0),(1,1))
    
    self.head_width = self.head_right[0][0]-self.head_left[0][0]
    self.head_width_inch = self.head_width/self.dpi
    ty = int(np.average([self.head_right[0][1],self.head_right[1][1],self.head_left[0][1],self.head_left[1][1]]))
    self.head_line = ((self.head_right[0][0],ty),(self.head_left[0][0],ty))

    if( shaft[0] is not None):
      self.shaft_left = self.sanitizeNP64(shaft[0].end_points)
    else:
      print "FAIL"
      self.shaft_left = ((0,0),(1,1))

    if( shaft[1] is not None):
      self.shaft_right = self.sanitizeNP64(shaft[1].end_points)
    else:
      print "FAIL"
      self.shaft_right = ((0,0),(1,1))

    self.shaft_width = self.shaft_right[0][0]-self.shaft_left[0][0]
    self.shaft_width_inch = self.shaft_width/self.dpi

    if( lbs[0] is not None):
      self.lbs_left = self.sanitizeNP64(lbs[0].end_points)
    else:
      print "FAIL"
      self.lbs_left = ((0,0),(1,1))

    if( lbs[1] is not None ):
      self.lbs_right = self.sanitizeNP64(lbs[1].end_points)
    else:
      self.lbs_right = ((0,0),(1,1))
   
    self.lbs_width = float(np.max([self.lbs_right[0][0],self.lbs_right[1][0]])-np.min([self.lbs_left[0][0],self.lbs_left[1][0]]))
    self.lbs_width_inch = self.lbs_width/self.dpi

    self.lbs_left_angle = self.angle_between(self.lbs_left,self.shaft_left)
    self.lbs_right_angle = self.angle_between(self.lbs_right,self.shaft_right)

    self.fillet_left = (float(fillet[0][0]),float(fillet[0][1]))
    self.fillet_right = (float(fillet[1][0]),float(fillet[1][1]))
    
    if( top is not None ):
      self.top = self.sanitizeNP64(top.end_points)
    else:
      self.top = ((0,0),(1,1))
    if( bottom is not None ):
      self.bottom  = self.sanitizeNP64(bottom.end_points)
    else:
      self.bottom = ((0,0),(1,1))
    x = bb[0] + bb[2]/2
    y = bb[1] + bb[3]/2 
    width = bb[2]
    height = bb[3]
    points = ((x, y), (x + width, y), (x + width, y + height), (x, y + height))
    super(FastenerFeature, self).__init__(img, x, y, points)             


class Fastener(base.InspectionPlugin):
  """
  Fastner
  """
  def clipAndRecenter(self,toClip,a,b,img,mode="horizontal"):
    """
    clip and recenter toClip to fit and be centered between a and b
    mode is the direction of the toclip
    """
    retVal = None
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

  def getLongestInROI(self,lines,roi, img, mode="vertical"):
    inRegion = FeatureSet([i for i in lines if i.isContainedWithin(roi)])
    inRegion = inRegion.sortLength()
    tolerance = 25
    if( len(inRegion) > 0 ):
        inRegion = inRegion.sortLength()
        best = inRegion[-1]        
        if( mode == "horizontal" ):
            test = best.y
            above = test+tolerance
            below = test-tolerance
            inRegion = FeatureSet([i for i in inRegion if(i.y < above and i.y > below )])
            xs = []
            for l in inRegion:
                xs.append(l.end_points[0][0])
                xs.append(l.end_points[1][0])
            ys = inRegion.y()
            xmin = np.min(xs)
            xmax = np.max(xs)
            y = np.average(ys)
            retVal=Line(img,((xmin,y),(xmax,y)))
        if( mode == "vertical" ):
            test = best.x
            right = test+tolerance
            left = test-tolerance
            inRegion = FeatureSet([i for i in inRegion if(i.x < right and i.x > left )])
            xs = inRegion.x()
            ys = []
            for l in inRegion:
                ys.append(l.end_points[0][1])
                ys.append(l.end_points[1][1])
            ymin = np.min(ys)
            ymax = np.max(ys)
            x = np.average(xs)
            retVal=Line(img,((x,ymin),(x,ymax)))
    else:
        retVal = None

    return retVal 

  def __call__(self, image):
    print "INSPECTION BEING EXECUTED"
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

    top = self.getLongestInROI(horizontal,(0,top_y,result.width,bolt_height/4), result, mode="horizontal")
    bottom = self.getLongestInROI(horizontal,(0,top_y+(3*bh4),result.width,bolt_height/4), result, mode="horizontal")
    #LOAD BEARING SURFACES
    lbs_left = self.getLongestInROI(horizontal,(0,bolt_y-bh4,result.width/2,bolt_height/2), result, mode="horizontal")
    lbs_right = self.getLongestInROI(horizontal,(bolt_x,bolt_y-bh4,result.width/2,bolt_height/2), result, mode="horizontal")

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
    shaft_left = self.getLongestInROI(vertical,(0,yavg,result.width/2,bolt_y+bolt_height-yavg), result, mode="vertical")
    shaft_right = self.getLongestInROI(vertical,(result.width/2,yavg,result.width/2,bolt_y+bolt_height-yavg), result, mode="vertical")
    head_left = self.getLongestInROI(vertical,(top_x,0,bolt_width/2,0.8*yavg), result, mode="vertical")
    head_right = self.getLongestInROI(vertical,(top_x+(bolt_width/2),0,(bolt_width/2),0.8*yavg), result, mode="vertical")

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

    print(head)
    feature = FastenerFeature(head,shaft,lbs,fillet,top,bottom,bb,result)
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

