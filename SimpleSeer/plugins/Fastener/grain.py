from SimpleCV import *
from fastener import *
import numpy as np
from ScannerUtil import *
def scanner_preprocess(img):
    retVal = straightenImg(img)
    if( retVal is None ):
        retVal = img
    return retVal

# def maxInWin(slice,ic,win):
#     result = []
#     w = len(slice)-2
#     for sp in ic:
#         ub = np.clip(sp+win,0,len(slice))
#         lb =np.clip(sp-win,0,len(slice))
#         mv = np.min(slice[lb:ub])
#         loc = np.where(slice[lb:ub]==mv)[0]
#         if(len(loc) == 1 ):
#             result.append(np.clip(loc[0]+lb,0,w))
#         else:
#             temp = (loc-(win))**2
#             idx = np.where(temp==np.min(temp))[0]
#             result.append(np.clip(loc[idx][0]+lb,0,w))
#     return result

# def getGrains(img,seeds=40,win=5):
#     retVal = []
#     seedpts = np.floor(np.linspace(0,img.width,seeds))
#     seedpts = maxInWin(img.getHorzScanlineGray(0),seedpts,win)
#     retVal.append(seedpts)
#     last = seedpts
#     for i in range(1,img.height):
#         sl = img.getHorzScanlineGray(i)
#         newPts = maxInWin(sl,last,win)
#         retVal.append(newPts) retVal = []
#     seedpts = np.floor(np.linspace(0,img.width,seeds))
#     seedpts = maxInWin(img.getHorzScanlineGray(0),seedpts,win)
#     retVal.append(seedpts)
#     last = newPts
    
#     retVal = np.vstack(retVal)
#     vectors = []
#     ys = range(0,img.height)
#     for i in range(0,seeds):
#         d = zip(retVal[:,i],ys)
#         last = d[0]
#         for ds in d:
#             img.drawLine(last,ds,color=Color.RED,thickness=2)
#             last = ds
#         vectors.append(d)

#     img.applyLayers()
#     return img

def getLocalMin(imgNP,pt,win):
    w = imgNP.shape[0]
    h = imgNP.shape[1]
    xmin = np.clip(pt[0]-win,0,w).astype(int)
    xmax = np.clip(pt[0]+win,0,w).astype(int)
    ymin = np.clip(pt[1]+1,0,h).astype(int)
    ymax = np.clip(pt[1]+(2*win)+1,0,h).astype(int)
    subimg = imgNP[xmin:xmax,ymin:ymax]
    meansx = np.mean(subimg,axis=1)
    minvx = np.min(meansx)
    meansy = np.mean(subimg,axis=0)
    minvy = np.min(meansy)

    xm = np.where(meansx==minvx)
    if(len(xm) > 1 ):
        print "MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
    ym = np.where(meansy==minvy)
    #x,y= np.where(subimg==minv)
    #dist = ((np.array(xm)-win)**2)
    #xloc = np.where(dist==np.min(dist))

    xf = pt[0]+xm[0]-((xmax-xmin)/2)
    yf = pt[1]+1#y[loc]+1
#    print xf[0],yf[0]
    return (xf[0],yf)

def getGrains2(img,seeds=20,win=3):
    retVal = []
    seedpts = np.floor(np.linspace(0,img.width,seeds))
    y = np.zeros([seeds])
    start_pts = zip(seedpts,y)
    ymax = img.height
    for pt in start_pts:
        print "Doing point"
        print pt
        line_pts = [pt]
        newPt = pt
        while(ymax-newPt[1] > win+1 ):
            newPt = getLocalMin(img.getGrayNumpy(),newPt,win)
            line_pts.append(newPt)
        retVal.append(line_pts)

    for r in retVal:
        prev = r[0]
        for p in r:
            img.drawLine(prev,p,color=Color.RED,thickness=3)
            prev = p
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
        rawData = rawData
        temp = Image((rawData.width,rawData.height))
        temp = temp.blit(rawData,mask=grain).smooth().smooth(aperature=15)
        result = getGrains2(rawData.equalize().invert().sobel(xorder=0))
        result.show()
        result.save(fname)

        
