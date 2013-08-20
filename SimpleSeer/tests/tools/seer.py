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
        for key in self.seer_instance.keys():
            self.kill_seer(key)

    def kill_seer(self,instance):
        print "killing {0}".format(instance)
        self.seer_instance[instance].terminate()
        del self.seer_instance[instance]

    def spinup_seer(self,type,config='./config/test_simpleseer.cfg',config_override={}):
        import argparse
        parser = argparse.ArgumentParser()
        parser.add_argument('-c', '--config', dest='config', default='.')
        ss = self.seer_types[type](parser)
        options = parser.parse_args()
        options.config = "./config/"
        ss.configure(options)
        for k,v in config_override.iteritems():
            setattr(ss, k, v)

        time.sleep(20)
        self.seer_instance[type] = Process(target=ss.run)
        self.seer_instance[type].start()
        time.sleep(3)
