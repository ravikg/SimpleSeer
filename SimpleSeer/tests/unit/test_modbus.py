import os, errno, shutil
import time
import unittest
import threading
import mock
import subprocess
from subprocess import *
from path import path

from SimpleSeer import Session
from SimpleSeer.modbus import ModBusService
from SimpleSeer.realtime import ChannelManager
from SimpleSeer.base import jsondecode
from pymodbus.server.sync import StartTcpServer
from pymodbus.device import ModbusDeviceIdentification
from pymodbus.datastore import ModbusSequentialDataBlock
from pymodbus.datastore import ModbusSlaveContext, ModbusServerContext
from pymodbus.client.sync import ModbusTcpClient as ModbusClient

import logging
log = logging.getLogger(__name__)


class ThreadWrapper (threading.Thread):
    def __init__(self, *args, **kwargs):
        threading.Thread.__init__(self, *args, **kwargs)
        self.args = kwargs['args']
        self.kwargs = kwargs['kwargs']

    def run(self):
        super(ThreadWrapper, self).run()

    def _stop(self):
        if self.isAlive():
            self._Thread__stop()

class TestModBus(unittest.TestCase):

    def test_modbus_coilread(self):

        self.config = dict(
            server = "localhost",
            port = 5021,
            tick = 2.0,
            digitalInputs = [{ 'pin': 0, 'message': { 'front_tire': True } }, { 'pin': 1, 'message': { 'rear_tire': True } }]
        )

        store = ModbusSlaveContext(di = ModbusSequentialDataBlock(0, [17]*100),co = ModbusSequentialDataBlock(0, [17]*100),hr = ModbusSequentialDataBlock(0, [17]*100),ir = ModbusSequentialDataBlock(0, [17]*100))
        context = ModbusServerContext(slaves=store, single=True)

        identity = ModbusDeviceIdentification()
        self.TcpServerThread = ThreadWrapper(name="TcpServerThread", target=StartTcpServer, args=(context,), kwargs={'identity':identity, 'address':(self.config['server'], self.config['port'])})
        self.TcpServerThread.start()

        self.ModBusServiceThread = ThreadWrapper(name="ModBusServerThread", target=ModBusService().start, args=(), kwargs={'verbose':True, 'config':self.config})
        self.ModBusServiceThread.start()

        self.TestClient = ModbusClient(self.config['server'], port=self.config['port'])
        self.cm = ChannelManager(shareConnection = False)

        self.written = False
        def log_write(msg):
            message = jsondecode(msg.body)
            self.written = True

        self.InputThread = self.cm.subscribe("modbusInput/", log_write, True)
        self.TestClient.write_coil(0, False)

        starttime = time.time()
        while self.written is False and time.time() - starttime < self.config['tick'] * 3:
            time.sleep(self.config['tick'])
            self.TestClient.write_coil(0, True)

        self.assertTrue(self.written)

        self.TestClient.write_coil(1, False)
        self.cm.publish("modbusOutput/", {"pin": 1, "message":True})
        time.sleep(1)
        self.assertTrue(self.TestClient.read_coils(1))

        for thread in threading.enumerate():
            if thread.__class__.__name__ is not "_MainThread":
                #print "Stopping ", thread.__class__.__name__
                thread._Thread__stop()
            
if __name__ == '__main__':
    unittest.main()