import re
import unittest
import subprocess
from SimpleSeer import models as M

class Test(unittest.TestCase):

    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_userAdd(self):
        dn = open("/dev/null")
        subprocess.call(['simpleseer','user','add', "-n", "John Doe", "-p", "wheresjane", 'testuser'], stderr=dn)
        self.assertEqual(len(M.User.objects), 1)
        self.assertEqual(M.User.objects[0].name, 'John Doe')
        self.assertEqual(M.User.objects[0].password, '3a8ff87b16f3c37ea016603cc64babf2')
        self.assertEqual(M.User.objects[0].username, 'testuser')

    def test_userRemove(self):
        dn = open("/dev/null")
        subprocess.call(['simpleseer','user','remove', '-f', 'testuser'], stderr=dn)
        self.assertEqual(len(M.User.objects), 0)