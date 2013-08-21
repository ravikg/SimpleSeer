import unittest
import time
from SimpleSeer.tests.tools.db import DBtools
from SimpleSeer.tests.tools.seer import SeerInstanceTools

class TestMongo(unittest.TestCase):
    dbcommands = {
        "slave": ["mongod", "--dbpath=/tmp/slave", "--logpath=/tmp/slave/mongod.log", "--port=27019", "--nojournal", "--noprealloc", "--oplogSize=100", "--replSet=rs0"],
        "arbiter": ["mongod", "--dbpath=/tmp/arbiter", "--logpath=/tmp/arbiter/mongod.log", "--port=27018", "--nojournal", "--noprealloc", "--oplogSize=100", "--replSet=rs0"],
        "master": ["mongod", "--dbpath=/tmp/master", "--logpath=/tmp/master/mongod.log", "--port=27020", "--nojournal", "--noprealloc", "--oplogSize=100", "--replSet=rs0"]
    }

    mongo_settings = {"host": "127.0.0.1:27019", "port":27019, "replicaSet": "rs0", "read_preference": 3}

    def setUp(self):
        self.dbs = DBtools(dbs=self.dbcommands)
        self.seers = SeerInstanceTools()

    def tearDown(self):
        self.dbs.killall_mongo()
        self.seers.killall_seer()

    def test_mongo_with_arbiter(self):
        self.dbs.spinup_mongo("master")
        self.dbs.spinup_mongo("slave")
        self.dbs.spinup_mongo("arbiter")
        resp = self.dbs.init_replset()
        resp_ok = resp.get('ok',0)
        self.assertEqual(resp_ok, 1.0)
        time.sleep(20)
        self.dbs.kill_mongo("master")
        time.sleep(20)
        self.seers.spinup_seer('web',config_override={"mongo":self.mongo_settings})
        self.seers.spinup_seer('olap',config_override={"mongo":self.mongo_settings})


suite = unittest.TestLoader().loadTestsFromTestCase(TestMongo)
unittest.TextTestRunner(verbosity=2).run(suite)
