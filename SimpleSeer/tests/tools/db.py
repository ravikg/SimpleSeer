
import mongoengine
from filesystem import delete_and_mkdir
import subprocess
import time
import socket
import logging
log = logging.getLogger()

class DBtools(object):
    db_instance = {}

    replConfig = {
        "_id" : "rs0",
        "version" : 1,
        "members" : [{
            "_id" : 0,
            "host" : "{}:27020".format(socket.gethostname())
        },{
            "_id" : 1,
            "host" : "{}:27019".format(socket.gethostname()),
            "priority" : 0.0001
        },{
            "_id" : 2,
            "host" : "{}:27018".format(socket.gethostname()),
            "arbiterOnly" : True
        }]}
    master = "127.0.0.1:27020"


    def __init__(self,*args,**kwargs):
    	self.dbs = kwargs.get('dbs',{})

    def spinup_mongo(self,type,postsleep=5):
        delete_and_mkdir("/tmp/{0}".format(type))
        self.db_instance[type] = subprocess.Popen(self.dbs[type])
        time.sleep(postsleep)

    def killall_mongo(self):
        for key in self.db_instance.keys():
            self.kill_mongo(key)

    def kill_mongo(self,instance):
        log.info("killing {0}".format(instance))
        self.db_instance[instance].kill()
        del self.db_instance[instance]


    def init_replset(self,postsleep=11):
        mongoengine.connection.disconnect()

        from pymongo import MongoClient
        from bson.code import Code
        conn = MongoClient(self.master)
        resp = conn.admin.command("replSetInitiate",self.replConfig)
        time.sleep(postsleep)
        return resp
