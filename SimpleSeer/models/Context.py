import mongoengine
from formencode import validators as fev
from formencode import schema as fes
#import formencode as fe

from SimpleSeer import validators as V
#from SimpleSeer import util

from SimpleSeer.models.base import SimpleDoc

class ContextSchema(fes.Schema):
    name = fev.UnicodeString(not_empty=True)
    options = V.JSON(if_empty={}, if_missing={})
    menuItems = fev.Set(if_empty=[], if_missing=[])

class Context(SimpleDoc, mongoengine.Document):
    name = mongoengine.StringField(default='')
    options = mongoengine.DictField(default={})
    menuItems = mongoengine.ListField(mongoengine.DictField(),default=[])

    def __repr__(self):
        return "%s Object <%s>" % (self.__class__.__name__, self.name)
        
    def __eq__(self, other):
        if isinstance(other, self.__class__):
            # Note: ignoring name to test if this context is functionally equivalent to other inspection (name is irrelevant)
            banlist = [None]
            params = [ a for a in self.__dict__['_data'] if not a in banlist ]
            
            for p in params:
                if self.__getattribute__(p) != other.__getattribute__(p):
                    return False
            return True            
        else:
            return False
          
    def save(self, *args, **kwargs):        
        # TODO: loop through all context and update like menu items where menuItem.unique == 0
        
        from SimpleSeer.realtime import ChannelManager
        
        super(Context, self).save(*args, **kwargs)
        ChannelManager().publish('meta/', self)


