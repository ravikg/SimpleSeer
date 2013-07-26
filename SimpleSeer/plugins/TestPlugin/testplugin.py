from SimpleSeer.plugins import base
from SimpleCV import Feature
from random import randint

"""
This creates dummy features for test purposes
Inspection simply creates a random integer
"""

class TestPlugin(base.InspectionPlugin):
    
    def __call__(self, image):
        f = Feature(image, 0, 0, [(0,0), (0,0), (0,0), (0,0)])
        f.testdata = randint(1, 100)
        
        return [f]
