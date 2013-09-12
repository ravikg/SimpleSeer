import time
from SimpleSeer.commands import core_commands
from SeerCloud.commands import olap
from SimpleSeer.worker import Foreman
import subprocess
import logging
log = logging.getLogger()

class WorkerInstanceTools(object):

    fm = Foreman()
    
    def __init__(self):

