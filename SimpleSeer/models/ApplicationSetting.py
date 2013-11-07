import mongoengine
from formencode import validators as fev
from formencode import schema as fes
from SimpleSeer.models.base import SimpleDoc


class ApplicationSettingSchema(fes.Schema):
    name = fev.UnicodeString()
    val = fev.UnicodeString(if_empty="", if_missing="")

class ApplicationSetting(SimpleDoc, mongoengine.Document):
    name = mongoengine.StringField(unique=True)
    val = mongoengine.StringField(default='')

    def __repr__(self):
        return "{} Object <{}>".format(self.__class__.__name__, self.name)

    def __eq__(self, other):
        if isinstance(other, self.__class__):
            # Note: ignoring name to test if this inspection is functionally equivalent to other inspection (name is irrelevant)
            banlist = [None, 'updatetime', 'name']
            params = [ a for a in self.__dict__['_data'] if not a in banlist ]
            
            for p in params:
                if self.__getattribute__(p) != other.__getattribute__(p):
                    return False
            return True
        else:
            return False
            
    def save(self, *args, **kwargs):        
        from SimpleSeer.realtime import ChannelManager
        super(ApplicationSetting, self).save(*args, **kwargs)
        ChannelManager().publish('meta/', self)


