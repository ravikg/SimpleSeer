from gevent import monkey
monkey.patch_all()

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
        
@core.state('scan')
def scan(state):
    core = state.core
    scan = core.cameras[0]

    scan.setROI()
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
        

    M.Alert.clear()
    M.Alert.redirect("frame/" + str(id))
    return core.state('waitforbuttons')

    
def process(frame):
    frame.features = []
    frame.results = []
    import pdb; pdb.set_trace()
    #k because we sometimes lose connection to mongo
    for inspection in M.Inspection.objects:
        if inspection.parent:
            return
        if inspection.camera and inspection.camera != frame.camera:
            return
        try:
            frame.features += inspection.execute(frame.image)
        except:
            frame.metadata['notes'] += "Inspection failed"
        
        for m in inspection.measurements:
            m.execute(frame, results)
    
