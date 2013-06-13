import yaml
import logging
import mongoengine
import os
import os.path
from path import path
from socket import gethostname
import logging
log = logging.getLogger()



class Session():
    """
    The session singleton must be instantiated with a configuration file reference
    as it's sole parameter before any of the SimpleSeer classes are imported.  This
    is due to all of Ming's relational computations happening at import-time,
    so a database connection must be provided.
    
    Once initialized, Session() can be used to reference configuration options
    globaly.  To refresh configuration options, simply call again with a different
    or updated config file.

    Session will default to "" any properties which are non-existant.  This is 
    nice, because it eliminates a lot of "try" blocks as you update the code
    (and potentially not the config file).  But it also can shoot you in the
    foot if you misspell property names.  Be careful!    
    """
    __shared_state = dict(
        _config = {})
    
    def __init__(self, yaml_config_dir = '', procname='simpleseer'):
        self.__dict__ = self.__shared_state
        
        if not yaml_config_dir:
            return  #return the existing shared context

        config_dict = self.read_config(yaml_config_dir)
        log.info("Loaded configuration from %s" % config_dict['yaml_config'])
        
        # Look for alternate config files with name hostname_simpleseer.cfg
        alt_config_filename = gethostname() + '_simpleseer.cfg'
        alt_config = path(yaml_config_dir) / alt_config_filename
        if os.path.isfile(alt_config):
            log.info('Overriding configuration with %s' % alt_config)
            alt_config_dict = yaml.load(open(alt_config))
            config_dict.update(alt_config_dict)
        
        self.configure(config_dict)
        if not self.procname:
            self.procname = procname
    
    @staticmethod
    def read_config(yaml_config_dir=''):
        yaml_config = path(yaml_config_dir) / "simpleseer.cfg"

        if yaml_config_dir == "." and not os.path.isfile(yaml_config):
            yaml_config_dir = "/etc/simpleseer"
            yaml_config = path(yaml_config_dir) / "simpleseer.cfg"
        retVal = yaml.load(open(yaml_config))
        retVal['yaml_config'] = yaml_config
        return retVal
    
    def configure(self, d):
        from .models.base import SONScrub
        self._config = d
        if self.mongo.get('master', False):
            master = self.mongo.pop("master")
            mongoengine.connect(self.database, **master)
        mongoengine.connect(self.database, **self.mongo)
        db = mongoengine.connection.get_db()
        db.add_son_manipulator(SONScrub())
        self.log = logging.getLogger(__name__)

    def camera_name(self, camera_id):
        for cam in self.cameras:
            if cam['id'] == camera_id:
                return cam['name']
        return None

    def get_config(self):
        return self._config

    def __getattr__(self, name):
        return self._config.get(name, '')
    
    def set_config(self,name,value):
        self._config[name] = value
    
    def __repr__(self):
        return "SimpleSeer Session Object"

#code to convert unicode to string
# http://stackoverflow.com/questions/956867/how-to-get-string-objects-instead-unicode-ones-from-json-in-python
def _decode_list(lst):
    newlist = []
    for i in lst:
        if isinstance(i, unicode):
            i = i.encode('utf-8')
        elif isinstance(i, list):
            i = _decode_list(i)
        newlist.append(i)
    return newlist

def _decode_dict(dct):
    newdict = {}
    for k, v in dct.iteritems():
        if isinstance(k, unicode):
            k = k.encode('utf-8')
        if isinstance(v, unicode):
             v = v.encode('utf-8')
        elif isinstance(v, list):
            v = _decode_list(v)
        newdict[k] = v
    return newdict   
    
