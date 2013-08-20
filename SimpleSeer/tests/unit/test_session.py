import os, errno, shutil
import time
import unittest

import mock
import subprocess
from subprocess import *

from path import path

from SimpleSeer import Session

# mkdir_p() taken from top rated comment on stackoverflow thread:
# http://stackoverflow.com/questions/600268/mkdir-p-functionality-in-python
def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc: # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else: raise

class Test(unittest.TestCase):

    def test_mongoconnection(self):

        _mongod = [line.strip() for line in open('./config/mongod.cfg')]

        # MongoDB no replset, forcemongomaster=false
        # This mongoengine connection does not check if it is master/slave so it should never raise an exception.
        try:
            shutil.rmtree('/tmp/slave')
            mkdir_p('/tmp/slave')
            _slave_options = _mongod[0].split()
            _mongod_slave = Popen(_slave_options, stdin=PIPE, stdout=PIPE, stderr=PIPE)
            time.sleep(3)
            session_slave = Session.Session(os.path.dirname(os.path.realpath(__file__)) + '/config/slave', 'corecommand')
            self.assertEqual(True, True)
        except Exception as inst:
            self.assertTrue(False)

        Session.__shared_state = { "config": {} }
        Session.mongoengine.connection.disconnect()

        # MongoDB with replset, forcemongomaster=true
        # This mongoengine connection checks to make sure it is master, if it is slave we expect for it to throw
        # an exception. Because the mongo instance is being initiated with replset and the connection is happening
        # within ~10 seconds, it should responsd with an db.command('isMaster') value of false 
        try:
            shutil.rmtree('/tmp/master')
            mkdir_p('/tmp/master')
            _master_options = _mongod[1].split()
            _mongod_master = Popen(_master_options, stdin=PIPE, stdout=PIPE, stderr=PIPE)
            time.sleep(3)
            session_master = Session.Session(os.path.dirname(os.path.realpath(__file__)) + '/config/master', 'corecommand')
            self.assertTrue(False)
        except Exception as inst:
            self.assertEqual(inst.args[0], "MongoDB must be the master!")

        Session.__shared_state = { "config": {} }
        Session.mongoengine.connection.disconnect()

        # Close the mongod processes
        _mongod_slave.kill()
        shutil.rmtree('/tmp/slave')
        _mongod_master.kill()
        shutil.rmtree('/tmp/master')