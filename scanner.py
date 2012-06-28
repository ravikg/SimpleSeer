import gc
import numpy as np
import SimpleSeer.models as M
from SimpleCV import Image
import math

@core.state('start')
def start(state):
    state.core.set_rate(10.0)
    return state.core.state('waitforbuttons')
    
@core.state('waitforbuttons')
def waitforbuttons(state):
    core = state.core
    while True:
        core.tick()
        scan = core.cameras[0]
        if scan.device.email or scan.device.file or scan.device.copy or scan.device.dev.get_option(30):
            return state.core.state('scan')

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
    

@core.state('scan')
def scan(state):
    core = state.core
    scan = core.cameras[0]
    
    scan.setProperty("resolution", 75)
    scan.setProperty("mode", "gray")
    M.Alert.clear()
    M.Alert.info("Preview scan, Please wait")
    preview = scan.getPreview()
    
    blobs = preview.stretch(25,255).findBlobs(minsize = 250)
    
    if not blobs:
      M.Alert.error("No part found, please reseat part close lid and retry")
      return core.state('waitforbuttons')

    topleft = list(blobs[-1].mBoundingBox[0:2])
    bottomright = [topleft[0] + blobs[-1].mBoundingBox[2], topleft[1] + blobs[-1].mBoundingBox[3]]

    topleft[0] = topleft[0] - 5
    topleft[1] = topleft[1] - 5
    
    bottomright[0] = bottomright[0] + 5
    bottomright[1] = bottomright[1] + 5  #5px margin


    scan.setROI(topleft, bottomright)
    scan.setProperty("resolution", 1200)
    scan.setProperty("mode", "color")
    
    M.Alert.clear()
    M.Alert.info("Scanning.... Please wait")
    id = '' 
    for frame in core.capture():
        img = frame.image
        numpdiff = (img - img.smooth()).getNumpy()
        rows = numpdiff.sum(1)
        rowsums = rows.sum(1)
        thresh = np.mean(rowsums) + np.std(rowsums) * 3
        stripe_rows = np.where(rowsums > thresh)
        if len(stripe_rows[0]):
            nump = img.getNumpy()
            for index in stripe_rows[0]:
                if index == 0 or index == img.width - 1:
                    continue
                stripe = nump[index,:]
                channels = np.where(stripe.min(0) > 10)
                for channel in channels:
                    nump[index,:,channel] = np.round(np.mean([nump[index-1,:,channel], nump[index+1,:,channel]], 0))
        
        #now straigten out the image
        temp = Image(nump)
        if( temp.width > 3500 or temp.height > 3500 ):
            M.Alert.error("WHOA NELLY! It appears your image is a little too big. Is the shroud over the scanner?")
            return core.state('waitforbuttons')        

        temp = straightenImg(temp)
        if( temp == None ):
            M.Alert.error("It appears your part is not sitting straight on the scanner, please try again.")
            return core.state('waitforbuttons')        

        frame.image = temp
               
        process(frame)
	t = frame.thumbnail
        frame.save()
        id = frame.id
        

    scan.setROI()
    M.Alert.clear()
    M.Alert.redirect("frame/" + str(id))
    return core.state('waitforbuttons')

    
def process(frame):
    frame.features = []
    frame.results = []
    for inspection in M.Inspection.objects:
        if inspection.parent:
            return
        if inspection.camera and inspection.camera != frame.camera:
            return
        results = inspection.execute(frame.image)
        frame.features += results
        for m in inspection.measurements:
            m.execute(frame, results)
    
