from .realtime import ChannelManager
from .base import jsondecode
from pymodbus.client.sync import ModbusTcpClient as ModbusClient
from .Session import Session 
import time
import logging
log = logging.getLogger(__name__)
"""
  @TODO:
    - Get all pins once, then check through config pins 
    UPDATE: Not sure if there is a way with pymodbus to grab all of the coil info
"""
class ModBusService(object):

    def start(self, verbose=False, config={}):
        if config.has_key('server'):
            modbus_settings = config
        else:
            modbus_settings = Session().modbus

        # Must have modbus settings in config to run
        if modbus_settings:
            if modbus_settings.has_key('server') and modbus_settings.has_key('port'):
                if verbose:
                    log.info('Trying to connect to Modbus Server[%s]...' % modbus_settings['server'])
                try:
                    # Connect the modbus client to the server
                    modbus_client = ModbusClient(modbus_settings['server'], port=modbus_settings['port'])
                except:
                    ex = 'Cannot connect to server %s, please verify it is up and running' % modbus_settings['server']
                    raise Exception(ex)
                if verbose:
                    log.info('...Connected to server %s' % modbus_settings['server'])

                # Function for writing to the output pin
                def write_output(msg):
                    message = jsondecode(msg.body)
                    if verbose:
                        log.info("modbusOutput/", message)
                    if message.has_key('pin') and message.has_key('message'):
                        # Set the pin value
                        modbus_client.write_coil(message['pin'], message['message'])

                # Subscribe to the output channel
                cm = ChannelManager(shareConnection = False)

                self.cmThread = cm.subscribe('modbusOutput/', write_output, True)

                # Get poll rate
                tick = modbus_settings.get('tick', 0.05)
                bits = []

                try:
                    for pin in modbus_settings['digitalInputs']:
                        # to work with anthony's system this was modbus_client.read_discrete_inputs(pin['pin']).bits[0]
                        bits.append(modbus_client.read_coils(pin['pin']).bits[0])
                except:
                    if self.cmThread.isAlive():
                        self.cmThread._stop()
                    raise Exception("It seems your modbus server is not available")
                while True:
                    try:
                        # Get current state of the bits
                        time.sleep(tick)
                        i = 0
                        # Publish any changes to modbusInput/
                        for pin in modbus_settings['digitalInputs']:
                            # to work with anthony's system this was modbus_client.read_discrete_inputs(pin['pin']).bits[0]
                            bit = modbus_client.read_coils(pin['pin']).bits[0]
                            if bits[i] is not bit:
                                cm.publish('modbusInput/', message = {'pin':pin['pin'], 'message':pin['message']})
                            bits[i] = bit
                            i += 1
                    except KeyboardInterrupt:
                        if self.cmThread.isAlive():
                            self.cmThread._stop()
                        ex = 'Keyboard Interrupt!'
                        raise Exception(ex)
            else:
                if verbose:
                    log.info('Please add a modbus server and port to your configuration file')
        else:
            if verbose:
                log.info('Please add a modbus entry in your configuration file')
