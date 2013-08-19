import mongoengine
import time
from multiprocessing import Process
from SimpleSeer.commands import core_commands
from SeerCloud.commands import olap



class SeerInstanceTools(object):
    seer_types = {
        "web" : core_commands.WebCommand,
        "olap" : olap.OLAPCommand
    }

    seer_instance = {}

    def killall_seer(self):
        for i,o in self.seer_instance.iteritems():
            print "killing {0}".format(i)
            o.terminate()


    def spinup_seer(self,type,config='./config/test_simpleseer.cfg',config_override={}):
        import argparse
        from SimpleSeer.Session import Session
        parser = argparse.ArgumentParser()
        parser.add_argument('-c', '--config', dest='config', default='.')
        #ss = core_commands.WebCommand(parser)
        ss = self.seer_types[type](parser)
        options = parser.parse_args()
        options.config = "./config/"
        ss.configure(options)
        for k,v in config_override.iteritems():
        	print k,v
        	setattr(ss, k, v)

        #print self.mongo_settings
        time.sleep(20)
        #print "====================================== RUN MONGO TESTS NOW ====================================================="
        #time.sleep(60)
        #mongoengine.connection.connect('test', **self.mongo_settings)
        #ss.session.mongo = self.mongo_settings
        
        #time.sleep(10)
        self.seer_instance[type] = Process(target=ss.run)
        self.seer_instance[type].start()
        time.sleep(3)
        #print self.seer_instance[type].communicate()
