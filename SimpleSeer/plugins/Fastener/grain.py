from SimpleCV import *
from fastener import *
import numpy as np
from ScannerUtil import *
def scanner_preprocess(img):
    retVal = straightenImg(img)
    if( retVal is None ):
        retVal = img
    return retVal

def maxInWin(slice,ic,win):
    result = []
    w = len(slice)-5
    for sp in ic:
        ub = np.clip(sp+win,0,len(slice)-1)
        lb =np.clip(sp-win,0,len(slice)-1)
        mv = np.max(slice[lb:ub])

        if(mv == 0):
            result.append(np.clip(sp,0,w))
        else:
            loc = np.where(slice[lb:ub]==mv)[0]
            if(len(loc) == 1 ):
                result.append(np.clip(loc[0]+lb,0,w))
            else:
                temp = (loc-sp)**2
                idx = np.where(temp==np.min(temp))[0]
                result.append(np.clip(loc[idx][0]+lb,0,w))
    return result

def getGrains(img,seeds=20,win=10):
    retVal = []
    seedpts = np.floor(np.linspace(0,img.width,seeds))
    seedpts = maxInWin(img.getHorzScanlineGray(0),seedpts,win)
    retVal.append(seedpts)
    last = seedpts
    for i in range(1,img.height):
        sl = img.getHorzScanlineGray(i)
        newPts = maxInWin(sl,last,win)
        retVal.append(newPts)
        last = newPts
    
    retVal = np.vstack(retVal)
    vectors = []
    ys = range(0,img.height)
    for i in range(0,seeds):
        d = zip(retVal[:,i],ys)
        last = d[0]
        for ds in d:
            img.drawLine(last,ds,color=Color.RED,thickness=2)
            last = ds
            #img[np.floor(ds[0]),np.floor(ds[1])]=Color.RED
        vectors.append(d)

    img.applyLayers()
    return img
        
path = ["./data/angle/","./data/flat/"]
i = 0 
for p in path:
    imset = ImageSet(p)
    for raw in imset:
        img = scanner_preprocess(raw)
        binary = img.threshold(20).dilate(3)
        temp = img.equalize().binarize(blocksize=15)
        b = temp.findBlobsFromMask(binary)
        fname = str(i)+".png"
        i = i + 1
        grain = b[-1].blobImage()
        grain = grain.crop(raw.width*(3/16.0),raw.height/8,raw.width*(9/16.0),raw.height/3)
        rawData = raw.crop(raw.width*(3/16.0),raw.height/8,raw.width*(9/16.0),raw.height/3)
        rawData = rawData.equalize()
        temp = Image((rawData.width,rawData.height))
        temp = temp.blit(rawData,mask=grain)
        result = getGrains(temp)
        result.show()
        result.save(fname)

        
