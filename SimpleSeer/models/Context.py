import mongoengine
from formencode import validators as fev
from formencode import schema as fes
#import formencode as fe

#from SimpleSeer import validators as V
#from SimpleSeer import util

from SimpleSeer.models.base import SimpleDoc

class ContextSchema(fes.Schema):
    name = fev.UnicodeString(not_empty=True)
    menuItems = fev.Set(if_empty=[], if_missing=[])

class Context(SimpleDoc, mongoengine.Document):
    name = mongoengine.StringField(default='')
    menuItems = mongoengine.ListField(mongoengine.DictField())

    def __repr__(self):
        return "[%s Object <%s> ]" % (self.__class__.__name__, self.name)
          
    def save(self, *args, **kwargs):        
        # TODO: loop through all context and update like menu items where menuItem.unique == 0
        
        from SimpleSeer.realtime import ChannelManager
        
        super(Context, self).save(*args, **kwargs)
        ChannelManager().publish('meta/', self)


