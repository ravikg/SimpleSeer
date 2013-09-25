import unittest
import time
import datetime
import json
import urllib2
from SimpleSeer.tests.tools.seer import SeerInstanceTools
from SimpleSeer import models as M

class Test(unittest.TestCase):
    
    def setUp(self):
        self.seers = SeerInstanceTools()

    def tearDown(self):
        self.frame.delete()
        self.seers.killall_seer()
    
    def test_modelschema(self):
        self.frame = M.Frame(
            capturetime=datetime.datetime.now(),
            notes="it worked",
            height=16,
            width=16,
            camera="invisible")
        self.frame.save()
        self.seers.spinup_seer("web")
        
        result = json.load(urllib2.urlopen("http://localhost:8080/api/frame/{}".format( str(self.frame.id) ) ))
        result_fields = [str(key) for key in result.keys()]
        
        missing_fields = []
        expected_fields = M.FrameSchema.fields              
        for field in expected_fields.keys():
            if(field not in result_fields):
                missing_fields.append(field)
        
        if(len(missing_fields) > 0):
            self.fail(
              "Missing expected field(s) `{}` in API frame request response.".format(
                '`, `'.join(missing_fields)))

suite = unittest.TestLoader().loadTestsFromTestCase(Test)
unittest.TextTestRunner(verbosity=2).run(suite)