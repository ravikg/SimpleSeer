import gc
import numpy as np
import SimpleSeer.models as M
#from SimpleCV import Image
from datetime import datetime # for frame capture faking
from SimpleCV import *
import math
from ScannerUtil import *
# for non-blocking io
import sys
import select

# I apologize for the globals but I am hacking a test harness
# There is a place in hell for me for global variables
# and a place in heave for duct-tape testing. 
testMode = True 
globalImSet = None 
globalPath = "/home/kscottz/SimpleSeer/SimpleSeer/plugins/Fastener/data/angle/"
globalCount = 0

#if( testMode ):
#    globalImSet = ImageSet(path)


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
        global testMode
        fakeScan = False
        if( testMode ):
            i,o,e = select.select([sys.stdin],[],[],0.0001)
            for s in i:
                if s == sys.stdin:
                    input = sys.stdin.readline()
                    if input is not None:
                        fakeScan = True
            
            if(fakeScan):
                return state.core.state('scan')
        else:
            if scan.device.email or scan.device.file or scan.device.copy or scan.device.dev.get_option(30):
                return state.core.state('scan')
        
@core.state('scan')
def scan(state):
    core = state.core
    scan = core.cameras[0]
    
    # This may be better living in SimpleSeer.py
    global testMode
    if( testMode ):
        global globalPath
        global globalImSet
        global globalCount
        if( globalImSet is None ):
            globalImSet = ImageSet(globalPath)
        M.Alert.info("Scanning.... Please wait")
        id = '' 
        if( globalCount > len(globalImSet) ):
            globalCount = 0
        img = globalImSet[globalCount]
        globalCount = globalCount + 1
        img = straightenImg(img)            
        frame = M.Frame(capturetime = datetime.utcnow(), 
                        camera= img.filename )
        frame.image = img
        process(frame)
        M.Alert.info("Straightening the image")
	t = frame.thumbnail
        frame.save()
        id = frame.id
        M.Alert.clear()
        M.Alert.redirect("frame/" + str(id))
        return core.state('waitforbuttons')

    
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
            img = Image(nump)
        #now straigten out the image
        if( img.width > 3500 or img.height > 3500 ):
            M.Alert.error("Image is too bright. Is the shroud over the scanner?")
            return core.state('waitforbuttons')        

        img = straightenImg(img)
        if( img == None ):
            M.Alert.error("It appears your part is not sitting straight on the scanner, please try again.")
            return core.state('waitforbuttons')        

        frame.image = img
               
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
        try:
            results = inspection.execute(frame.image)
        except:
            if 'notes' not in frame.metadata:
                frame.metadata['notes'] = ''
            else:
                frame.metadata['notes'] += " "
            
            frame.metadata['notes'] += "Inspection failed"
        
        frame.features += results
        for m in inspection.measurements:
            m.execute(frame, results)
    
