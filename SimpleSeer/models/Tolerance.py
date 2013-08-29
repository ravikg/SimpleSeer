import mongoengine
from formencode import validators as fev
from formencode import schema as fes
#import formencode as fe

from SimpleSeer import validators as V
#from SimpleSeer import util

from SimpleSeer.models.base import SimpleDoc

class ToleranceSchema(fes.Schema):
    measurement_id = fev.UnicodeString(not_empty=True)
    criteria = V.JSON(if_empty={}, if_missing={})
    rule = V.JSON(if_empty={}, if_missing={})

class Tolerance(SimpleDoc, mongoengine.Document):
    measurement_id = mongoengine.ObjectIdField(default=None)
    criteria = mongoengine.DictField(default={})
    rule = mongoengine.DictField(default={})

    def save(self, *args, **kwargs):        
        from SimpleSeer.realtime import ChannelManager
        
        super(Tolerance, self).save(*args, **kwargs)
        ChannelManager().publish('meta/', self)


