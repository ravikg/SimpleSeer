import time
from multiprocessing import Process
from SimpleSeer.commands import core_commands
from SeerCloud.commands import olap
import logging
log = logging.getLogger()


import subprocess


class SeerInstanceTools(object):
    seer_types = {
        "web" : core_commands.WebCommand,
        "olap" : olap.OLAPCommand
    }

    seer_instance = {}

    def killall_seer(self):
        for key in self.seer_instance.keys():
            self.kill_seer(key)

    def old_kill_seer(self,instance):
        log.info("killing {0}".format(instance))
        self.seer_instance[instance].terminate()
        del self.seer_instance[instance]

    def kill_seer(self,instance):
        log.info("killing {0}".format(instance))
        self.seer_instance[instance].kill()
        del self.seer_instance[instance]

    def spinup_seer(self, type, config='./config/test_simpleseer.cfg', config_override={} ):
        args = ['simpleseer','--config-override={}'.format(config_override),type]
        self.seer_instance[type] = subprocess.Popen(args)
        time.sleep(10)
        #(stdout, stderr) = self.seer_instance[type].communicate()
        #print stdout, stderr

    def old_spinup_seer(self,type,config='./config/test_simpleseer.cfg',config_override={}):
        import argparse
        parser = argparse.ArgumentParser()
        parser.add_argument('-c', '--config', dest='config', default='.')
        parser.add_argument('--configoverride', dest='config_override', default=config_override)
        ss = self.seer_types[type](parser)
        options = parser.parse_args()
        options.config = "./config/"
        ss.configure(options)
        #for k,v in config_override.iteritems():
        #    setattr(ss.session, k, v)
        time.sleep(20)
        self.seer_instance[type] = Process(target=ss.run)
        self.seer_instance[type].start()
        time.sleep(3)
