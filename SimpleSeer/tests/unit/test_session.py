import time
import unittest

import mock

from SimpleSeer import Session

class TestMongoConnection(unittest.TestCase):

    def test_mongoconnection(self):
        try:
            session = Session.Session('.', 'corecommand')
            self.assertEqual(True, True)
        except Exception as inst:
            self.assertEqual(inst.args[0], "MongoDB must be the master!")

if __name__ == '__main__':
    unittest.main()