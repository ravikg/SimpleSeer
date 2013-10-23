import time
from SimpleSeer.commands import core_commands
from SimpleSeer.commands import manage
from SeerCloud.commands import olap
import subprocess
import logging
log = logging.getLogger()

class SeerInstanceTools(object):
    seer_types = {
        "web" : core_commands.WebCommand,
        "olap" : olap.OLAPCommand,
        "worker" : manage.WorkerCommand
    }

    seer_instance = {}

    def killall_seer(self):
        for key in self.seer_instance.keys():
            self.kill_seer(key)

    def kill_seer(self,instance):
        log.info("killing {0}".format(instance))
        self.seer_instance[instance].kill()
        del self.seer_instance[instance]

    def spinup_seer(self, type, config='./config/test_simpleseer.cfg', config_override={}, pipe=None):
        args = ['simpleseer','--config-override={}'.format(config_override), type]
        self.seer_instance[type] = subprocess.Popen(args, stdout=pipe, stderr=pipe)
        time.sleep(10)
        #(stdout, stderr) = self.seer_instance[type].communicate()
        #print stdout, stderr
