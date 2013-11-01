import unittest
import sys
from SeerCloud.testdata import TestData
from SimpleSeer.worker import Foreman
from SimpleSeer.Session import Session
from SimpleSeer.states import Core
from SimpleSeer.tests.tools.seer import SeerInstanceTools
from SimpleSeer.tests.tools.db import DBtools

import logging
log = logging.getLogger(__name__)

class Test(unittest.TestCase):
    
    testData = None
    fm = None
    core = Core(Session('.'))
    dbcommands = {
        "master": ["mongod", "--dbpath=/tmp/master", "--logpath=/tmp/master/mongod.log", "--port=27020", "--nojournal", "--noprealloc", "--oplogSize=100"]
    }       
    config_override = {"database":"test","mongo":{"host": "127.0.0.1:27020", "port":27020}}

    def setUp(self):
        self.dbs = DBtools(dbs=self.dbcommands)
        self.dbs.spinup_mongo("master",10)
        self.dbs.connect(self.config_override) 
        self.seers = SeerInstanceTools()
        #import pdb; pdb.set_trace()

        self.testData = TestData()
        self.testData.makeMeasurements(1)
        self.testData.makeFrames(5)
        self.fm = Foreman()
        
    def tearDown(self):
        self.testData.remove()        
        del self.testData    
        del self.fm
        self.dbs.killall_mongo()

    def testWorker(self):
        
        self.fm._useWorkers = self.fm.workerRunning()
        self.assertTrue(self.fm._useWorkers, 'Worker is not detected.  Is it running?')
        
        if self.fm._useWorkers:
            # Construct features/results using worker
            log.info('Running worker tests')
            for idx, f in enumerate(M.Frame.objects(id__in=self.testData.addedFrames)):
                log.info('Processing frame {} of {}'.format(idx + 1, len(self.testData.addedFrames)))
                f.results = []
                self.core.process(f)
                f.save()
            
            # Each frame should have one feature
            # That feature should have a featuredata point named testdata
            for f in M.Frame.objects(id__in=self.testData.addedFrames):
                print "("* 10
                print len(f.features)
                self.assertEqual(len(f.features), 1, 'Expected exactly one feature')
                if len(f.features):
                    self.assertIn('testdata', f.features[0].featuredata, 'Expected feature data not found on frame')

            # Each frame should have one result
            # And that result should have a non-None numeric value
            for f in M.Frame.objects(id__in=self.testData.addedFrames):
                self.assertEqual(len(f.results), 1, 'Expected exactly one result')
                if len(f.results):
                    self.assertIsNot(f.results[0].numeric, None, 'Result should not be None')
                    self.assertEqual(f.features[0].featuredata['testdata'], f.results[0].numeric, 'Result does not match corresponding feature data')
        else:
             log.warn('Worker is not running.  Tests skipped.')

    def testSerial(self):
        
        # Construct features/results using serial
        self.fm._useWorkers = False
        co = Core(Session('.'))
        log.info('Running serial tests')
        for idx, f in enumerate(M.Frame.objects(id__in=self.testData.addedFrames)):
            log.info('Processing frame {} of {}'.format(idx + 1, len(self.testData.addedFrames)))
            f.results = []
            self.core.process(f)
            f.save()
        
        # Each frame should have one feature
        # That feature should have a featuredata point named testdata
        for f in M.Frame.objects(id__in=self.testData.addedFrames):
            self.assertEqual(len(f.features), 1, 'Expected exactly one feature')
            if len(f.features):
                self.assertIn('testdata', f.features[0].featuredata, 'Expected feature data not found on frame')

        # Each frame should have one result
        # And that result should have a non-None numeric value
        for f in M.Frame.objects(id__in=self.testData.addedFrames):
            self.assertEqual(len(f.results), 1, 'Expected exactly one result')
            if len(f.results):
                self.assertIsNot(f.results[0].numeric, None, 'Result should not be None')
                self.assertEqual(f.features[0].featuredata['testdata'], f.results[0].numeric, 'Result does not match corresponding feature data')