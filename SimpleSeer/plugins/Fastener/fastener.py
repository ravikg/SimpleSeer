import numpy as np

import SimpleCV
from SimpleCV import Image, Color, FeatureSet, Feature, Line
import numpy as np
from SimpleSeer import models as M
from SimpleSeer import util
from scipy import optimize
import warnings

#counter = 0

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
    
    x0 = (v1[0][0]-v1[1][0])
    y0 = (v1[0][1]-v1[1][1])
    p0=np.array([x0,y0])
    p0=p0/np.sqrt(np.vdot(p0,p0))
    


    x1 = np.array([v2[0][0]-v2[1][0]])
    y1 = np.array([v2[0][1]-v2[1][1]])
    p1=np.array([x1,y1])
    p1=p1/np.sqrt(np.vdot(p1,p1))

    dot = np.vdot(p0,p1)
    if( dot == 0 ):
      retVal = 90
    else:
      retVal = float((np.arccos(dot)*360.0)/(np.pi*2))
    
    return retVal

  def __init__(self,head,shaft,lbs,fillet,top,bottom,bb,img,dpi=1200):
    self.dpi = dpi
    inches_to_mm = 25.4
    #FML numpy.F64 sanitization
    if( head[0] is not None):
      self.head_left = self.sanitizeNP64(head[0].end_points)
    else:
      warnings.warn("could not find left side of head")
      self.head_left = ((0,0),(1,1))

    if( head[1] is not None):
      self.head_right = self.sanitizeNP64(head[1].end_points)
    else:
      warnings.warn("could not find right side of head")
      self.head_right = ((0,0),(1,1))
    
    self.head_width = self.head_right[0][0]-self.head_left[0][0]
    self.head_width_mm = (self.head_width/self.dpi)*inches_to_mm
    ty = int(np.average([self.head_right[0][1],self.head_right[1][1],self.head_left[0][1],self.head_left[1][1]]))
    self.head_line = ((self.head_right[0][0],ty),(self.head_left[0][0],ty))

    if( shaft[0] is not None):
      self.shaft_left = self.sanitizeNP64(shaft[0].end_points)
    else:
      warnings.warn("could not find left side of shaft")
      self.shaft_left = ((0,0),(1,1))

    if( shaft[1] is not None):
      self.shaft_right = self.sanitizeNP64(shaft[1].end_points)
    else:
      warnings.warn("could not find right side of shaft")
      self.shaft_right = ((0,0),(1,1))

    self.shaft_width = np.max([self.shaft_right[0][0],self.shaft_right[1][0]])-np.min([self.shaft_left[0][0],self.shaft_left[1][0]])
    self.shaft_width_mm = (self.shaft_width/self.dpi)*inches_to_mm
    ty = int(np.average([self.shaft_right[0][1],self.shaft_right[1][1],self.shaft_left[0][1],self.shaft_left[1][1]]))
    self.shaft_line = ((self.shaft_right[0][0],ty),(self.shaft_left[0][0],ty))

    if( lbs[0] is not None):
      self.lbs_left = self.sanitizeNP64(lbs[0].end_points)
    else:
      warnings.warn("could not find left bearing surface")
      self.lbs_left = ((0,0),(1,1))

    if( lbs[1] is not None ):
      self.lbs_right = self.sanitizeNP64(lbs[1].end_points)
    else:
      warnings.warn("could not find right bearing surface")
      self.lbs_right = ((0,0),(1,1))
   
    self.lbs_width = float(np.max([self.lbs_right[0][0],self.lbs_right[1][0]])-np.min([self.lbs_left[0][0],self.lbs_left[1][0]]))
    self.lbs_width_mm = (self.lbs_width/self.dpi)*inches_to_mm
    ty = int(np.average([self.lbs_right[0][1],self.lbs_right[1][1],self.lbs_left[0][1],self.lbs_left[1][1]]))
    xleft = np.min([self.lbs_left[0][0],self.lbs_left[1][0]])
    xright = np.max([self.lbs_right[0][0],self.lbs_right[1][0]])
    self.lbs_line = ((xright,ty),(xleft,ty))

    self.lbs_left_angle = self.angle_between(self.lbs_left,self.shaft_left)
    self.lbs_right_angle = self.angle_between(self.lbs_right,self.shaft_right)

    self.fillet_left = (float(fillet[0][0][0]),float(fillet[0][0][1]))#(float(fillet[0][0]),float(fillet[0][1]))
    self.fillet_right = (float(fillet[1][0][0]),float(fillet[1][0][1]))#(float(fillet[1][0]),float(fillet[1][1]))
    self.fillet_left_r = float(fillet[0][1])
    self.fillet_right_r = float(fillet[1][1])
    
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
  
  def fitFillet(self,roi,img):
    img = img.crop(roi[0],roi[1],roi[2],roi[3])
    npimg = img.getGrayNumpy()
    x,y = np.where(npimg > 128)
    if( len(x) < 10 or len(y) < 10 ):
      return None
    x_m = np.average(x)
    y_m = np.average(y)
    def calc_R(xc, yc):
      return np.sqrt((x-xc)**2 + (y-yc)**2)
    
    def f_2(c):
      Ri = calc_R(*c)
      return Ri - Ri.mean()
  
    center_estimate = x_m, y_m
    center_2, ier = optimize.leastsq(f_2, center_estimate)
    
    xc_2, yc_2 = center_2
    Ri_2       = calc_R(*center_2)
    R_2        = int(Ri_2.mean())
    residu_2   = sum((Ri_2 - R_2)**2)
    if( R_2 == 0 ):
      R_2 = 1
    return((int(xc_2+roi[0]),int(yc_2+roi[1])),R_2)

  def getLongestInROI(self,lines,roi, img, mode="vertical"):
    inRegion = lines.filter([l.isContainedWithin(roi) for l in lines])
    inRegion = inRegion.sortLength()
    tolerance = 25
    if( len(inRegion) > 0 ):
        inRegion = inRegion.sortLength()
        best = inRegion[-1]        
        if( mode == "horizontal" ):
            test = best.y 
            # find all of the lines in our region 
            above = test+tolerance
            below = test-tolerance
            inRegion = FeatureSet([i for i in inRegion if(i.y < above and i.y > below )])
            # estimate the optimal line length 
            xs = []
            for l in inRegion:
                xs.append(l.end_points[0][0])
                xs.append(l.end_points[1][0])
            ys = inRegion.y()
            xmin = np.min(xs)
            xmax = np.max(xs)
            y = np.average(ys)
            # this aggregate line of all our line segments j
            # becomes the basis of our least squares fit.             
            retVal=Line(img,((xmin*1.02,y),(xmax*.98,y)))
            retVal = img.fitLines([retVal.end_points])[0]

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
            retVal=Line(img,((x,ymin*1.02),(x,ymax*.98)))
            retVal = img.fitLines([retVal.end_points])[0]
    else:
        warnings.warn("Couldn't find line in ROI")
        retVal = None

    return retVal 

  def __call__(self, image):
    params = None
    if( self.inspection is not None ):
      params = util.utf8convert(self.inspection.parameters)
    retVal = []
    
    result = image
    #flood fill ro remove noise
    result = result.floodFill(np.array([(20,20)]),20,color=Color.BLACK)

    #binary = result.threshold(30).dilate(2)
    #b = result.findBlobsFromMask(mask=binary)
    binary = Image((result.width,result.height))
    b = result.findBlobs()
    #edgeImg = binary.blit(b[-1].blobMask(),b[-1].topLeftCorner()).edges()
    fastener = b[-1]
    fastener.image = binary
    b[-1].drawOutline(color=(255,255,255))
    edgeImg = binary.applyLayers() * 2
    
    #global counter
    #fname = str(counter)+".png"
    #counter = counter + 1
    #edgeImg.save(fname)
    l = edgeImg.findLines(threshold=10,minlinelength=15 )#,cannyth1=40,cannyth2=120,maxlinegap=2)
    #b = result.findBlobsFromMask(mask=binary)
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
    vertical = l.filter(np.abs(l.angle()) > v) #FeatureSet([i for i in l if (i.angle() > v) or (i.angle() < -1*v)])

    h = 5
    horizontal = l.filter(np.abs(l.angle()) < h) #FeatureSet([i for i in l if (i.angle() < h) and (i.angle() > -1*h)])

    top = self.getLongestInROI(horizontal,(0,top_y,result.width,bolt_height/4), edgeImg, mode="horizontal")
    bottom = self.getLongestInROI(horizontal,(0,top_y+(3*bh4),result.width,bolt_height/4), edgeImg, mode="horizontal")
    #LOAD BEARING SURFACES
    lbs_left = self.getLongestInROI(horizontal,(0,bolt_y-bh4,result.width/2,bolt_height/2), edgeImg, mode="horizontal")
    lbs_right = self.getLongestInROI(horizontal,(bolt_x,bolt_y-bh4,result.width/2,bolt_height/2), edgeImg, mode="horizontal")

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
        return []

    # use the load bearing surfaces to segment out the head and shaft
    shaft_left = self.getLongestInROI(vertical,(0,yavg,edgeImg.width/2,bolt_y+bolt_height-yavg), edgeImg, mode="vertical")
    shaft_right = self.getLongestInROI(vertical,(edgeImg.width/2,yavg,edgeImg.width/2,bolt_y+bolt_height-yavg), edgeImg, mode="vertical")
    head_left = self.getLongestInROI(vertical,(top_x,0,bolt_width/2,0.8*yavg), edgeImg, mode="vertical")
    head_right = self.getLongestInROI(vertical,(top_x+(bolt_width/2),0,(bolt_width/2),0.8*yavg), edgeImg, mode="vertical")

    # now render
    if( bottom is not None):
        if( shaft_left is not None and
            shaft_right is not None ):
            bottom = self.clipAndRecenter(bottom,shaft_left,shaft_right,result,"")

    if( top is not None):
        if( head_left is not None and
            head_right is not None ):
            top = self.clipAndRecenter(top,head_left,head_right,result,"")

    
    head = (head_left, head_right)
    shaft = (shaft_left, shaft_right)
    lbs = (lbs_left, lbs_right)

    
    froi = 50
    fl = None
    fr = None
    while( fl == None or fr == None ):
      fl=self.fitFillet((shaft_left.x-(froi*.75),lbs_left.y-(froi*.75),froi,froi),edgeImg)
      fr=self.fitFillet((shaft_right.x-(froi*.25),lbs_right.y-(froi*.75),froi,froi),edgeImg)
      if( fl is None or fr is None ):
        froi = froi * 1.2


    max_fillet_sz = 100 

    #clean up fillet stuff
    if( fl[1] > max_fillet_sz and fr[1] > max_fillet_sz ):
      # we totally failed just throw in the towel 
      fl = ((shaft_left.x,lbs_left.y),2)
      fr = ((shaft_right.x,lbs_right.y),2)
    elif( fl[1] > max_fillet_sz ):
      #estimate the left from the right
      sw = shaft_right.x - shaft_left.x
      #get the offset of the shaft to the fillet
      foff = fr[0][0]-shaft_right.x 
      fl = ((fr[0][0]-(2*foff)-sw,fr[0][1]),fr[1])
    elif( fr[1] > max_fillet_sz ):
      #estimate the left from the right
      sw = shaft_right.x - shaft_left.x
      #get the offset of the shaft to the fillet
      foff = shaft_left.x-fl[0][0]
      fr = ((fl[0][0]+sw+(2*foff),fl[0][1]),fl[1])


    fillet = [fl,fr]
      
    #fillet = ((shaft_left.x,lbs_left.y),(shaft_right.x,lbs_right.y))
    bb = (top_x,top_y,bolt_width,bolt_height)

    ff = M.FrameFeature()
    feature = FastenerFeature(head,shaft,lbs,fillet,top,bottom,bb,result)
    ff.setFeature(feature)
    retVal.append(ff)

    if( params is not None and params.has_key("saveFile") ):
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

