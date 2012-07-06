from SimpleCV import * 
from fastener import *
import numpy as np
from ScannerUtil import *
def scanner_preprocess(img):
    retVal = straightenImg(img)
    if( retVal is None ):
        retVal = img
    return retVal

def extract_measurements(img,bolt_type='angle'):
    f = Fastener(None)
    retVal = f(img)
    return retVal

def renderHarness(img,fastener):
    t = 3
    img.drawLine(fastener.head_left[0],fastener.head_left[1],color=Color.WHITE, thickness = t)
    img.drawLine(fastener.head_right[0],fastener.head_right[1],color=Color.WHITE, thickness = t)

    img.drawLine(fastener.shaft_left[0],fastener.shaft_left[1],color=Color.YELLOW, thickness = t)
    img.drawLine(fastener.shaft_right[0],fastener.shaft_right[1],color=Color.YELLOW, thickness = t)
    
    img.drawLine(fastener.lbs_left[0],fastener.lbs_left[1],color=Color.ORANGE, thickness = t)
    img.drawLine(fastener.lbs_right[0],fastener.lbs_right[1],color=Color.ORANGE, thickness = t)

    img.drawLine(fastener.top[0],fastener.top[1],color=Color.BLUE, thickness = t)
    img.drawLine(fastener.bottom[0],fastener.bottom[1],color=Color.BLUE, thickness = t)

#    img.drawCircle(fastener.fillet_left[0],10,color=Color.ORANGE,thickness=t)
#    img.drawCircle(fastener.fillet_right[0],10,color=Color.ORANGE,thickness=t)

    img = img.applyLayers()
    

    return img

path = "./data/angle/"
imset = ImageSet(path)
i = 0 
for raw in imset:
    img = scanner_preprocess(raw)
    result = extract_measurements(img)
    print result 
    if( len(result) == 0 ):
        continue
    result_img = renderHarness(img,result[0].getFeature())
    print result_img
    final =result_img.sideBySide(img)
    fname = "./results/result"+str(i)+".png"
    final.scale(0.4).show()
    final.save(fname)
    i = i + 1
