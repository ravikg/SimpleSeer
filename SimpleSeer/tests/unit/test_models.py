import unittest
from datetime import datetime

import mock
from SimpleCV.ImageClass import Image
from SimpleSeer.tests.tools.db import DBtools

from SimpleSeer import models as M

class Test(unittest.TestCase):

    dbcommands = {
        "master": ["mongod", "--dbpath=/tmp/master", "--logpath=/tmp/master/mongod.log", "--port=27020", "--nojournal", "--noprealloc", "--oplogSize=100"]
    }    

    @mock.patch('SimpleSeer.realtime.ChannelManager')
    def setUp(self, cm):
        self.dbs = DBtools(dbs=self.dbcommands)
        self.dbs.spinup_mongo("master",10)        
        img = Image('lenna')
        frame = M.Frame(capturetime=datetime.utcnow(), camera='test')
        frame.image = img
        self.frame = frame
        self.frame.save()

    def tearDown(self):
        self.dbs.killall_mongo()

    def test_get_image_in_cache(self):
        assert isinstance(self.frame.image, Image)

    def test_get_image_from_db(self):
        frame = M.Frame.objects[0]
        assert isinstance(frame.image, Image)

    def test_serialize(self):
        result = self.frame.serialize()
        self.assertEqual(
            sorted(result.keys()),
            [ 'content_type', 'data' ])
        assert result['content_type'] in ('image/webp', 'image/jpeg')