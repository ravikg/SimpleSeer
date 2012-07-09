from SimpleCV import *
from fastener import *
import numpy as np
from ScannerUtil import *
def scanner_preprocess(img):
    retVal = straightenImg(img)
    if( retVal is None ):
        retVal = img
    return retVal

path = ["./data/angle/","./data/flat/"]
i = 0 
for p in path:
    imset = ImageSet(p)
    for raw in imset:
        img = scanner_preprocess(raw)
        temp = img.equalize().binarize(blocksize=15).erode() #sobel(aperature=7).edges()
        fname = str(i)+".png"
        i = i + 1
        temp.save(fname)
        temp.scale(.5).show()
