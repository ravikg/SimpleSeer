#!/usr/bin/python

from SimpleSeer.Session import Session
cfg = Session("/etc/simpleseer.cfg")

import SimpleSeer.models as M
from SimpleSeer.models import Frame, Inspection
from ScannerUtil import straightenImg

from SimpleSeer.states import Core

Core(cfg)


inspections = Inspection.objects(method = "fastener")

if not len(inspections):
   insp = Inspection(name = 'fastener', method = 'fastener') 
   insp.save()
else:
   insp = inspections[0]


for f in Frame.objects.order_by("-capturetime"):
    print "analysing features for frame %s" % str(f.id)
    try:
        img = f.image
        if not img:
           Exception("couldn't read image")
    except:
        print "could not read image for frame %s" % str(f.id)
        continue
    if img.width > 5000:
        print "skipping frame too wide"
        continue
        
    img = straightenImg(img)
    if not img:
       r
    if "FastenerFeature" in [feat['featuretype'] for feat in f.features]:
        f.features = [feat for feat in f.features if feat['featuretype'] != 'FastenerFeature']
    
    try:
        f.features += insp.execute(img)
    except Exception as e:
        print e
        f.metadata['notes'] = "Inspection failed"
    
    f.thumbnail_file.delete()
    f.image = img
    f.save()
    print "saved features for frame %s" % str(f.id)
    
        

