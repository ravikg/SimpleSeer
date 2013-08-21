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
    
    def __init__(self, yaml_config_dir = '.', procname='simpleseer', config_override={}):
        self.__dict__ = self.__shared_state
        
        if self._config != {}:
            return  #return the existing shared context
        self.config_override = config_override

        config_dict = self.read_config(yaml_config_dir)
        for k,v in config_override.iteritems():
            config_dict[k] = v
        log.info("Loaded configuration from %s" % config_dict['yaml_config'])        
        self.configure(config_dict)
        if not self.procname:
            self.procname = procname
    
        #self.appname = self.get_app_name('.')

        self.appname = self.database
        self._known_triggers = {}
    
    @staticmethod
    def read_config(yaml_config_dir='.', yaml_config_file="simpleseer.cfg"):
        yaml_config = path(yaml_config_dir) / yaml_config_file

        if yaml_config_dir == "." and not os.path.isfile(yaml_config):
            yaml_config_dir = "/etc/simpleseer"
            yaml_config = path(yaml_config_dir) / yaml_config_file
        retVal = yaml.load(open(yaml_config))
        retVal['yaml_config'] = yaml_config

        # Look for alternate config files with name hostname_simpleseer.cfg
        alt_config_filename = "{0}_{1}".format(gethostname(),yaml_config_file)
        alt_config = path(yaml_config_dir) / alt_config_filename
        if os.path.isfile(alt_config):
            log.info('Overriding configuration with %s' % alt_config)
            alt_config_dict = yaml.load(open(alt_config))
            retVal.update(alt_config_dict)

        return retVal
    
    def configure(self, d):
        from .models.base import SONScrub
        self._config = d
        if not hasattr(self, 'database') or self.database == '':
            raise Exception('Database not defined in config')
        if not hasattr(self, 'mongo') or self.mongo == '':
            raise Exception('Mongo not defined inconfig')
        
        if self.mongo.get('master', False):
            master = self.mongo.pop("master")
            mongoengine.connect(self.database, **master)
        mongoengine.connect(self.database, **self.mongo)
        db = mongoengine.connection.get_db()

        if self.forcemongomaster:
            if db.command('isMaster')['ismaster']:
                log.info("MongoDB isMaster: true")
            else:
                log.info("MongoDB isMaster: false")
                raise Exception("MongoDB must be the master!")
        
        db.add_son_manipulator(SONScrub())
        self.log = logging.getLogger(__name__)
        
    def camera_name(self, camera_id):
        for cam in self.cameras:
            if cam['id'] == camera_id:
                return cam['name']
        return None

    def get_app_name(self, basedir='.'):
        from os import listdir
        from os.path import join, isdir
        dirs = [ d for d in os.listdir(basedir) if isdir(join(basedir, d)) and d not in ['SimpleSeer', 'SeerCloud'] ]
 
        for d in dirs:
            path, localdirs, localfiles = os.walk(basedir + '/' + d).next()
            
            if '__init__.py' in localfiles:
                return d
                
        return ''
        
    def get_triggers(self, app, model, pre):
        from .models.base import checkPreSignal, checkPostSignal
                
        if not (app, model, pre) in self._known_triggers:
            if pre == 'pre':
                self._known_triggers[(app, model, pre)] = checkPreSignal(model, app)
            elif pre == 'post':
                self._known_triggers[(app, model, pre)] = checkPostSignal(model, app)
                
        return self._known_triggers[(app, model, pre)]
            

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
    
