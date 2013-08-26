import unittest
import time
from SimpleSeer.tests.tools.db import DBtools
from SimpleSeer.models import Tolerance, Measurement
from SimpleSeer.worker import Foreman
from SimpleSeer.tests.tools.seer import SeerInstanceTools

class TestMeasurement(unittest.TestCase):
    dbcommands = {
        "master": ["mongod", "--dbpath=/tmp/master", "--logpath=/tmp/master/mongod.log", "--port=27020", "--nojournal", "--noprealloc", "--oplogSize=100"]
    }

    config_override = {"database":"test","mongo":{"host": "127.0.0.1:27020", "port":27020}}

    measurement = None
    tolerance = None

    def setUp(self):
        self.dbs = DBtools(dbs=self.dbcommands)
        self.dbs.spinup_mongo("master",10)
        self.dbs.connect(self.config_override)
        #self.fm = Foreman()
        self.seers = SeerInstanceTools()
        self.seers.spinup_seer('olap',config_override={"mongo":self.config_override})

    def tearDown(self):
        self.teardown_tolerance()
        self.dbs.killall_mongo()
        self.seers.killall_seer()

    def setup_tolerance(self):
        self.teardown_tolerance()
        self.measurement = Measurement()
        self.measurement.save()
        self.assertTrue( len(self.measurement.tolerance_list) == 0 )
        self.tolerance = Tolerance(None,{"criteria":"testkey","rule":{"operator":"<","value":0}})
        self.tolerance.save()
        #if not self.fm.workerRunning():
        #    assertTrue(False) #check to see if worker is running.  if not, use worker tools

        print "tolerance setup complete"

    def teardown_tolerance(self):
        if self.tolerance:
            self.tolerance.delete()
            self.tolerance = None
        if self.measurement:
            self.measurement.delete()
            self.measurement = None


    def test_tolerance_create(self):
        self.setup_tolerance()
        # apply tolerance to measurement
        self.measurement.tolerance_list.append(self.tolerance)
        self.measurement.save()

        # reload measurement from db
        self.measurement.reload()
        print self.measurement

        ## check that tolerance is on tolerance_list
        #self.assertTrue( self.measurement.tolerance_list[0].id == self.tolerance.id )
        # 
        # delete tolerance
        # reload measurement from db
        ## check that tolerance_list is empty
        #delete measurement
        #self.assertTrue(False)
        self.teardown_tolerance()
"""
    def test_tolerance_change(self):
        # create measurement
        # create tolerance
        # add tolerance to measurement
        ## check that tolerance values == measurement.tolerance_list[0].values
        # change tolerance value
        ## check that check that tolerance values != measurement.tolerance_list[0].values
        # save tolerance
        ## check that tolerance values == measurement.tolerance_list[0].values
        # delete tolerance
        # delete measurement
        self.assertTrue(False)

    def test_backfill(self):

        #Measurement.objects()[0].backfillTolerances()
        self.assertTrue(False)
"""

suite = unittest.TestLoader().loadTestsFromTestCase(TestMeasurement)
unittest.TextTestRunner(verbosity=2).run(suite)
