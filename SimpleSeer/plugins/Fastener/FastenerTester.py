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
    return Fastener(img)

def renderHarness(img,fastner):
    print fastner
    return img

path = "./data/angle/"
imset = ImageSet(path)
i = 0 
for raw in imset:
    img = scanner_preprocess(raw)
    result = extract_measurements(img)
    print result 
    print img
    result_img = renderHarness(img,result)
    print result_img
    final =result_img.sideBySide(img)
    fname = "./results/result"+str(i)+".png"
    final.save(fname)
    i = i + 1
