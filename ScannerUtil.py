import numpy as np
from SimpleCV import Image
import math

def straightenImg(img):
    print img.width
    print img.height
    mask = img.threshold(20).dilate(2)
    #TRY TO GET THE BOLD ALLIGNED RIGHT
    #Try to figure out which side is most massive by color
    UH = mask.crop(0,0,img.width,img.height/2).meanColor()[0]
    BH = mask.crop(0,img.height/2,img.width,img.height/2).meanColor()[0]
    RH = mask.crop(0,img.width/2,img.width/2,img.height).meanColor()[0]
    LH = mask.crop(0,0,img.width/2,img.height).meanColor()[0]
    sidethresh = 3
    if( RH > sidethresh*LH ):
        img = img.rotate(90,fixed=False)
        mask = img.threshold(20).dilate(2)
    elif( LH > sidethresh*RH):
        img = img.rotate(-90,fixed=False)
        mask = img.threshold(20).dilate(2)
    
    if( BH > UH ):
        img = img.rotate(180,fixed=False)
        mask = img.threshold(20).dilate(2)

    b = img.findBlobsFromMask(mask,minsize=250)
    outer = b[-1].mMask.edges()
    lines = outer.findLines()
    angles = lines.angle()
    #go through our lines and pick the near vertical and 
    # horizontal lines that have the greatest numbers of samples 
    a = 30
    testhp = angles[(angles<a)&(angles>0)]
    testhn = angles[(angles>-1*a)&(angles<0)]
    a = 70
    testvp = -1*(90-angles[(angles>a)])
    testvn = -1*(-90-angles[(angles<-1*a)])
    values = [testhp,testhn,testvp,testvn]
    #get the one with the most values
    counts = [len(testhp),len(testhn),len(testvp),len(testvn)]
    best = np.argmax(counts)
    #take the median of these to filter out outliers
    final_rotation = np.median(values[best])
    print '=========================================='
    print final_rotation
    print values
    print counts
    if np.max(counts) < 10 or math.isnan(final_rotation):
        return None
    else:
        return img.rotate(final_rotation,fixed=False)   
    
