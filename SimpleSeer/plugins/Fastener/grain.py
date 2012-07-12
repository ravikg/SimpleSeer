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

def getLocalMin(imgNP,pt,prevPt,win):
    w = imgNP.shape[0]
    h = imgNP.shape[1]
    xmin = np.clip(pt[0]-win,0,w).astype(int)
    xmax = np.clip(pt[0]+win,0,w).astype(int)
    ymin = np.clip(pt[1]+1,0,h).astype(int)
    ymax = np.clip(pt[1]+win*2+1,0,h).astype(int)
    subimg = imgNP[xmin:xmax+1,ymin:ymax+1]
    meansx = np.mean(subimg,axis=1)
    minvx = np.min(meansx)
    meansy = np.mean(subimg,axis=0)
    minvy = np.min(meansy)

    xm = np.where(meansx==minvx)[0][0]
    ym = np.where(meansy==minvy)[0][0]
    #x,y= np.where(subimg==minv)
    #dist = ((np.array(xm)-win)**2)
    #xloc = np.where(dist==np.min(dist))
    print (xmin,xmax,pt[0])
    print subimg.shape
    if(minvx > 200):
        xf = (pt[0]-prevPt[0])
    else:
        xf = xm-win

    if(np.fabs(xf) == win and minvy < 52 and np.random.rand(1)[0] > 0.2):
        xf = xf*2
        yf = 0
    else :
        yf = win/2
#    if(minvy > 128 ):
 #       yf = 1
 #   else:
 #       yf = 1#ym+1#y[loc]+1
 #   print xf,yf
    pVec = [(pt[0]-prevPt[0]),(pt[1]-prevPt[1])]
    cVec = [xf,yf]
    #calculate the direction as the sum of the prior and our current estimate
    xd = xf#(pVec[0]+cVec[0])/2
    yd = yf#(pVec[1]+cVec[1])/2
    # print "###################################"
    # print "last point    " +str(pt)
    # print "old direction " +str(pVec)
#    print "cur direction " + str((xf,yf))
    # print "sug direction " +str((xd,yd))
    xf = np.round(pt[0]+xd)
    yf = np.round(pt[1]+yd)
#    print (xf,yf)
#    time.sleep(1)
#    print "nex point     " + str((xf,yf))
    return (np.clip(xf,0,w),np.clip(yf,0,h))


# def generateSteeringArray(win):
#     x = np.mgrid[0:(2*win)+1,(-1*win):win+1][1]
#     y = np.mgrid[0:(2*win)+1,0:(2*win)+1][0]
#     r = np.sqrt((x*x)+(y*y))
#     print r
#     tx = x/r
#     ty = y/r 
#     return tx,ty
    
def getGrains2(img,seeds=40,win=6):
    retVal = []
    seedpts = np.floor(np.linspace(0,img.width,seeds))
    y = np.zeros([seeds])
    start_pts = zip(seedpts,y)
    ymax = img.height
    for pt in start_pts:
        print "Doing point"
        print pt
        line_pts = [pt]
        nextPt = pt
        prevPt = np.array([pt[0],-2])
        while(ymax-nextPt[1] > win+1 ):
           currentPt = getLocalMin(img.getGrayNumpy(),nextPt,prevPt,win)
           prevPt = nextPt            
           nextPt = currentPt

           line_pts.append(nextPt)
        retVal.append(line_pts)

    for r in retVal:
        prev = r[0]
        for p in r:
            img.drawLine(prev,p,color=Color.RED,thickness=2)
            prev = p
    return img 

def grainFlow3(img,slices=15):
    sw = img.height/slices
    # b = img.findBlobs(minsize=9)
    # # b = FeatureSet([ml for ml in b if ml.area() < 200])
    # # b2 = FeatureSet([ml for ml in b if np.fabs(ml.angle()) > 45])
    # # metric = float(len(b2))/float(len(b))
    # # metric = metric / float(img.area())
    # # b = metric*1000000
    # b = b.aspectRatios()
    # total = len(b)
    # b = len([bs for bs in b if bs > .8 and bs < 1.2])
    # metric = (float(b)/float(total))/(float(img.area()))
    # b = metric * 10000000
    # b = np.clip(np.round(b),1,5)
    # print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    # print b
    # print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    result = []
    for i in range(0,slices):
        sample = img.crop(0,i*sw,img.width,sw)
        #l=sample.findLines(threshold=10)#threshold=1,minlinelength=10,maxlinegap=3,cannyth1=50, cannyth2=100)
        l = sample.findBlobs(minsize=11)
        l = FeatureSet([ml for ml in l if ml.area() < sample.width*sample.height/20])
        l1 = FeatureSet([ml for ml in l if np.fabs(ml.angle()) > 45])
        l2 = FeatureSet([ml for ml in l if np.fabs(ml.angle()) <= 45])
        l1.draw(color=Color.RED,width=2)
        l2.draw(color=Color.BLUE,width=2)
        sample.show()
        v = np.mean(np.fabs(l.angle()))
        result.append(v)
        if( v < 45.0 ):
            img.dl().rectangle((0,i*sw),(img.width,sw),color=Color.BLUE,filled=True,alpha=100)
        else:
            img.dl().rectangle((0,i*sw),(img.width,sw),color=Color.RED,filled=True,alpha=100)
    #img.dl().ezViewText(str(b),(20,20))
    return img.applyLayers()
        
   
path = ["./data/angle/","./data/flat/"]
i = 0 
for p in path:
    imset = ImageSet(p)
    for raw in imset:
        img = scanner_preprocess(raw)
        #build the mask to get bolt
        binary = img.threshold(20).dilate(3) 
        #and get the grain image
        temp = img.equalize().binarize(blocksize=15)
        # get the biggest blob's grain image
        b = temp.findBlobsFromMask(binary)
        grain = b[-1].blobImage()
        # now do the same for the raw area
        b = img.findBlobsFromMask(binary)
        raw = b[-1].blobImage()
        # lob off the head approximately
        grain = grain.crop(raw.width*(3/16.0),raw.height/8,raw.width*(9/16.0),raw.height/3)
        raw = raw.crop(raw.width*(3/16.0),raw.height/8,raw.width*(9/16.0),raw.height/3)

        result = grainFlow3(grain)
        result.show()

        fname = str(i)+".jpg"
        i = i + 1
        result.save(fname)

        