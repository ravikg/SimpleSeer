from SimpleSeer import models as M
from SimpleSeer.plugins import base
import SimpleCV


class FaceFeature(SimpleCV.HaarFeature):
    pass


class Face(base.InspectionPlugin):
  
    def printFields(cls):
        return ['x', 'y', 'height', 'width', 'area']
          
    def __call__(self, image):
        #params = util.utf8convert(self.parameters)
        
        faces = image.findHaarFeatures("face")
        
        if not faces:
            return []
        
        return faces
