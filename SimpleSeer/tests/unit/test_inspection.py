import unittest
from SimpleSeer.Session import Session
from SimpleSeer.models.Inspection import Inspection
import pkg_resources

class Test(unittest.TestCase):

    def test_load_pass(self):
    	Inspection.register_plugins('seer.plugins.inspection')

    def test_load_fail(self):
    	self.assertRaises(ImportError , Inspection.register_plugins, 'seer.plugins.testfail')