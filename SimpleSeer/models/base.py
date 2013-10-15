import time
import logging
from cPickle import dumps, loads
from datetime import datetime
import calendar

import bson
import mongoengine
import pkg_resources
import sys
from pymongo.son_manipulator import SONManipulator

from SimpleCV import Image

log = logging.getLogger(__name__)
log.addHandler(logging.NullHandler())


# Look for entry ponts for pre- and post-save functions
def checkPreSignal(model, app):
    return checkSignal(model, app, 'presave')

def checkPostSignal(model, app):
    return checkSignal(model, app, 'postsave')

def checkSignal(model, app, pre):
    mods = []
    for ep in pkg_resources.iter_entry_points('{}.{}.triggers.{}'.format(app, model, pre)):
        mods.append(__import__(ep.module_name, globals(), locals(), [ep.name]).__getattribute__(ep.attrs[0])())
        
    return mods

class Picklable(object):
    _jsonignore = [None]

    #TODO: move into son manipulators
    def __getstate__(self):
        ret = {}
        
        if hasattr(self, 'id'):
            ret['id'] = self.id

        for k in self._data.keys():
            #if k == 'capturetime':
            #    import pdb; pdb.set_trace()
            if k == 'id': continue
            
            if not k:
                continue

            v = self._data[k]
            if k[0] == "_" or k in self._jsonignore:
                continue
            if (hasattr(v, "__json__")):
                ret[k] = v.__json__()
            #elif isinstance(v, datetime):
            #    ret[k] = calendar.timegm(v.timetuple())
            elif isinstance(v, mongoengine.fields.GridFSProxy):
                if v is None:
                    ret[k] = None
                else:
                    ret[k] = "/grid/"+k+"/" + str(self.imgfile.grid_id)
                    ret[k]
            elif k == 'features':
                feats = []
                for feat in v:
                    feat_dict = feat._data
                    if 'featurepickle_b64' in feat_dict:
                        feat_dict.pop('featurepickle_b64')
                    feats.append(feat_dict)
                ret[k] = feats
            else:
                ret[k] = v

        return ret
        
    def __setstate__(self, state):
        from bson import ObjectId
        import mongoengine
        from datetime import datetime
        from .FrameFeature import FrameFeature
        
        if not '_data' in self:
            self._data = {}
        
        self._changed_fields = []
        for k, v in state.iteritems():
            if k == 'id':
                self._data[None] = ObjectId(v)
                self.id = ObjectId(v)
            elif k == 'imgfile':
                grid_id = state['imgfile'][-24:]
                self._data['imgfile'] = mongoengine.fields.GridFSProxy(ObjectId(grid_id))
            elif k == 'capturetime':
                self._data[k] = datetime.utcfromtimestamp(v)
            elif k == 'features':
                feats = []
                for feat in v:
                    feature = FrameFeature()
                    feature._data = feat
                    feature.inspection = ObjectId(feature.inspection)
                    feats.append(feature)
                self.features = feats
            else:
                self._data[k] = v
            
            self._dynamic_fields = bson.son.SON()
        
class SimpleDoc(Picklable):
    meta=dict(auto_create_index=True)

    def update_from_json(self, d):
        for k,v in d.items():
            setattr(self, k, v)

class SimpleEmbeddedDoc(Picklable):
    """
    Any embedded docs (for object trees) should extend SimpleEmbeddedDoc
    """
    pass

class WithPlugins(object):

    def get_plugin(self, name):
        '''Get a named plugin and instantiate it with the model instance'''
        try:
            PluginClass = self._plugins[name]
        except AttributeError:
            cls = self.__class__
            raise ValueError, ('No plugins registered on %r, maybe you need to'
                               'call %s.register_plugins(group)?' %
                               (cls, cls.__name__))
        except KeyError:
            raise ValueError, ('Plugin not found: %s. Valid plugins: %r' %
                               (name, self._plugins.keys()))
        try:
            return PluginClass(self)
        except TypeError:
            return PluginClass()

    @classmethod
    def register_plugins(cls, group):
        if not hasattr(cls, '_plugins'):
            cls._plugins = {}
        plugins = cls._plugins
        for ep in pkg_resources.iter_entry_points(group):
            log.info('Loading %s plugin %s', group, ep.name)
            plugins[ep.name] = ep.load()
        return plugins

class SONScrub(SONManipulator):
    _bson_primitive_types = (
        int, float, basestring, datetime,
        type(None),
        bson.RE_TYPE, bson.Code, bson.Binary,
        bson.DBRef, bson.ObjectId)
    _serializers = {}
    _deserializers = {0x80: lambda v,c: loads(v)}

    class Missing(object): pass

    @classmethod
    def clear_registry(cls):
        result = cls._serializers, cls._deserializers
        cls._serializers = {}
        cls._deserializers = {0x80: lambda v,c: loads(v)}
        return result

    @classmethod
    def restore_registry(cls, registry):
        cls._serializers, cls._deserializers = registry

    @classmethod
    def scrub_type(cls, type):
        cls._serializers[type] = (cls._scrub, None)

    @classmethod
    def register_bsonifier(cls, type, serialize):
        cls._serializers[type] = (serialize, None)

    @classmethod
    def register_bintype(cls, type, serialize, deserialize, type_id=None):
        # 0x80 is reserved (by me!) for pickling
        if type_id is None:
            type_id = 0x81
            while type_id in cls._deserializers:
                type_id += 1
            if type_id > 0xff:
                raise ValueError, 'All custom type_ids are already taken'
        if type_id in cls._deserializers:
            raise ValueError, 'type_id %d is already taken' % type_id
        existing = cls._find_serializer(type)
        if existing[0]:
            raise ValueError, 'Ambiguous registration of type %r' % (
                type)
        cls._serializers[type] = (serialize, type_id)
        cls._deserializers[type_id] = deserialize
        return type_id

    @classmethod
    def register_pickled_type(cls, type):
        cls._serializers[type] = (cls._pickle, 0x80)

    def transform_incoming(self, son, collection):
        if isinstance(son, self._bson_primitive_types):
            pass
        elif isinstance(son, (list, tuple)):
            son = [ self.transform_incoming(v, collection) for v in son ]
            son = [ v for v in son if v is not self.Missing ]
        elif isinstance(son, dict):
            son = [
                (k, self.transform_incoming(v, collection))
                for k,v in son.items()]
            son = dict((k,v) for k,v in son if v is not self.Missing)
        else:
            (serializer, type_id) = self._find_serializer(type(son))
            if serializer is not None:
                son = serializer(son, collection)
                if type_id is not None:
                    son = bson.Binary(son, type_id)
        return son

    def transform_outgoing(self, son, collection):
        """
        if isinstance(son, (list, tuple)):
            son = [ self.transform_outgoing(v, collection) for v in son ]
        elif isinstance(son, dict):
            son = dict(
                (k, self.transform_outgoing(v, collection))
                for k,v in son.items())
        elif isinstance(son, bson.Binary) and son.subtype & 0x80:
            deserializer = self._deserializers.get(son.subtype)
            if deserializer is not None:
                son = deserializer(son, collection)
        """
        return son

    @classmethod
    def _find_serializer(cls, sontype):
        for test_type in sontype.__mro__:
            result = cls._serializers.get(test_type, None)
            if result is not None: return result
        return (None, None)

    @classmethod
    def _scrub(cls, son, collection):
        return cls.Missing

    @classmethod
    def _pickle(cls, son, collection):
        return bson.Binary(dumps(son, protocol=-1))
