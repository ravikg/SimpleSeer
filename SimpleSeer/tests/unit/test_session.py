import os, errno, shutil
import time
import unittest

import mock
import subprocess
from subprocess import *

from path import path

from SimpleSeer import Session

def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc: # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else: raise

class TestMongoConnection(unittest.TestCase):

    def test_mongoconnection(self):

        _mongod = [line.strip() for line in open('./config/mongod.cfg')]

        # Check slave version
        try:
            shutil.rmtree('/tmp/slave')
            mkdir_p('/tmp/slave')
            _slave_options = _mongod[0].split()
            _mongod_slave = Popen(_slave_options, stdin=PIPE, stdout=PIPE, stderr=PIPE)
            time.sleep(3)
            session_slave = Session.Session(os.path.dirname(os.path.realpath(__file__)) + '/config/slave', 'corecommand')
            self.assertEqual(True, True)
        except Exception as inst:
            self.assertEqual(inst.args[0], "MongoDB must be the master!")

        Session.__shared_state = { "config": {} }
        Session.mongoengine.connection.disconnect()

        # Check master version
        try:
            shutil.rmtree('/tmp/master')
            mkdir_p('/tmp/master')
            _master_options = _mongod[1].split()
            _mongod_master = Popen(_master_options, stdin=PIPE, stdout=PIPE, stderr=PIPE)
            time.sleep(3)
            session_master = Session.Session(os.path.dirname(os.path.realpath(__file__)) + '/config/master', 'corecommand')
            self.assertEqual(True, True)
        except Exception as inst:
            self.assertEqual(inst.args[0], "MongoDB must be the master!")
            

if __name__ == '__main__':
    unittest.main()