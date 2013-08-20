from .realtime import ChannelManager
from .base import jsondecode
from pymodbus.client.sync import ModbusTcpClient as ModbusClient
from .Session import Session 
import time
import logging
log = logging.getLogger(__name__)
"""
  @TODO:
    - Wrap all log in verbose
    - Get rid of multiple channel managers
    - Get all pins once, then check through config pins

"""
class ModBusService(object):

    def start(self, verbose=False):
        modbus_settings = Session().modbus
        # Must have modbus settings in config to run
        if modbus_settings:
            if modbus_settings.has_key('server'):
                if verbose:
                    log.info('Trying to connect to Modbus Server[%s]...' % modbus_settings['server'])
                try:
                    # Connect the modbus client to the server
                    modbus_client = ModbusClient(modbus_settings['server'])
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

                cmThread = cm.subscribe('modbusOutput/', write_output, True)

                # Get poll rate
                tick = modbus_settings.get('tick', 0.05)
                bits = []
                for pin in modbus_settings['digitalInputs']:
                    bits.append(modbus_client.read_discrete_inputs(pin['pin']).bits[0])
                while True:
                    try:
                        # Get current state of the bits
                        time.sleep(tick)
                        i = 0
                        # Publish any changes to modbusInput/
                        for pin in modbus_settings['digitalInputs']:
                            bit = modbus_client.read_discrete_inputs(pin['pin']).bits[0]
                            if bits[i] is not bit:
                                cm.publish('modbusInput/', message = {'pin':pin['pin'], 'message':pin['message']})
                            bits[i] = bit
                            i += 1
                    except KeyboardInterrupt:
                        if cmThread.isAlive():
                            cmThread._stop()
                        ex = 'Keyboard Interrupt!'
                        raise Exception(ex)
            else:
                if verbose:
                    log.info('Please add a modbus server to your configuration file')
        else:
            if verbose:
                log.info('Please add a modbus entry in your configuration file')