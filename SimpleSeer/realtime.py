import amqp
from socketio.namespace import BaseNamespace
import gevent
import threading
from time import sleep
import socket

from functools import partial

from .Session import Session
from .base import jsonencode, jsondecode

import logging
log = logging.getLogger(__name__)


# Thread class for handling asyncronous channel subscriptions
class SubscribeThread (threading.Thread):
    def __init__(self, channel, exchange, callback):
        threading.Thread.__init__(self)
        self.cm = ChannelManager(shareConnection = False)
        self.channel = channel
        self.exchange = exchange
        self.callback = callback

    def run(self):
        while True:
            try:
                self.channel.wait()
            except (socket.error, IOError) as e:
                conn = self.cm.connect(re_establish=True)
                self.channel = self.cm.setup_channel(conn, self.exchange, self.callback)
            
    def _stop(self):
        if self.isAlive():
            self._Thread__stop()

# Main class for handling pub/sub with our broker
class ChannelManager(object):
    
    def __init__(self, shareConnection=True, max_tries=1000000):
        self._init = True
        self._config = Session()
        self._response = {}
        # Defaults to a ridiculous number -- we want our connections to keep trying to
        # Connect to rabbitmq until monitor pulls it back up.
        self._max_tries = max_tries 
        
        # Greenlets don't like shared connections
        self._shareConnection = shareConnection
        if shareConnection:
            self._connection = self.connect()
            
    def __repr__(self):
        return '<ChannelManager>' 
    
    # Establishes a connection with our broker and returns that connection
    # Automatically returns an already established connection unless re_establish is True or _shareConnection is False
    def connect(self, re_establish=False):
        if not hasattr(self._config, 'rabbitmq') or self._config.rabbitmq == '':
            raise Exception('Rabbit MQ parameter not set in configuration')

        # Return self._connection if it's available, otherwise, continue with establishing connection
        if self._shareConnection and re_establish is False:
            try:
                return self._connection
            except Exception as e:
                pass
                #log.warn("Was unable to use self._connection: {}".format(e))

        tries = 0

        # Attempt to connect until we have a connection or we exceed max_tries
        while True:
            # If we exceed max tries, raise an exception. 
            # All services will exceed the monitor's max_tries limit allowing monitor to restart broker.
            if tries > self._max_tries:
                log.warn('Was unable to establish a rabbitmq connection!')
                raise Exception
            try:
                return amqp.Connection(host=self._config.rabbitmq)
            except (socket.error, IOError) as e:
                log.warn('Socket connection error: {}.  Waiting 0.1 seconds.'.format(e))
                tries += 1
                sleep(0.1) # This value is now hardcoded. Larger values will never reconnect after RabbitMQ failure

    # Takes an exchange and a message and publishes it to our broker.  
    def publish(self, exchange, message):
        conn = self.connect()

        channel = self.safeChannel(conn)
        channel.exchange_declare(exchange=exchange, type='fanout')

        msg = amqp.Message(jsonencode(message))
        
        self.safePublish(channel, msg=msg, exchange=exchange, routing_key='')
        channel.close()

    # Default channel setup
    def setup_channel(self, conn, exchange, callback):
        channel = self.safeChannel(conn)
        
        channel.exchange_declare(exchange=exchange, type='fanout')
        (queue_name, msgs, consumers) = channel.queue_declare(exclusive=True)
        
        channel.queue_bind(exchange=exchange, queue=queue_name)
        channel.basic_consume(callback=callback, queue=queue_name)
        
        return channel

    # Blocking channel wait
    def channel_wait(self, channel):
        while True:
            try:
                channel.wait()
            except (socket.error, IOError) as e:
                log.warn('Socket error: {}.  Will try to reconnect.'.format(e))
                conn = self.connect(re_establish=True)
                channel = self.setup_channel(conn, exchange, callback)

    # Subscribes to an exchange with a callback func.  Sync by default, pass async=True for asynchronous glory 
    def subscribe(self, exchange, callback, async=False):                  
        conn = self.connect()
        log.info('Subscribe to %s' % exchange)  

        channel = self.setup_channel(conn, exchange, callback)

        if async:
            # Non-blocking threaded channel.wait()
            thread = SubscribeThread(channel, exchange, callback)
            thread.daemon = True
            thread.start()
            return thread
        else:
            # Blocking channel.wait()
            self.channel_wait(channel)

    # Wrapper func that loops channel.basic_publish until it is able to publish successfully
    def safePublish(self, channel, **kwargs):
        pubed = False 
        while not pubed:
            try:
                channel.basic_publish(**kwargs)
                pubed = True
            except (socket.error, IOError) as e:
                log.warn('Error when publishing request: {}.  Reconnecting'.format(e))
                conn = self.connect(re_establish=True)

                if self._shareConnection:
                    self._connection = conn
                
                channel = self.safeChannel(conn)
                
    # Wrapper func that loops conn.channel() until it is able to create the channel successfully
    def safeChannel(self, conn):
        while True:
            try:
                return conn.channel()
            except (socket.error, IOError) as e:
                log.warn('Error when creating channel: {}.  Reconnecting'.format(e))
                conn = self.connect(re_establish=True)
                
                if self._shareConnection:
                    self._connection = conn
    
    
    # RPC style pub/sub, publishes a message, subscribes to a queue, and then returns the response
    def rpcSendRequest(self, workQueue, request):
        from random import choice
        
        conn = self.connect()
        
        corrid = ''.join([ choice('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ') for i in range(20) ])
        self._response[corrid] = None
        
        def on_response(msg):
            if corrid == msg.properties['correlation_id']:
                self._response[corrid] = jsondecode(msg.body)
                
        def setup_channel(callback_queue):
            channel = self.safeChannel(conn)
            
            if not callback_queue:
                (callback_queue, msgs, consumers) = channel.queue_declare(exclusive=True)
                
            channel.basic_consume(callback=on_response, no_ack=True, queue=callback_queue)
            return channel, callback_queue
        
        channel, callback_queue = setup_channel(None)
        channel.basic_consume(callback=on_response, no_ack=True, queue=callback_queue)
        
        msg = amqp.Message(jsonencode(request))
        msg.properties['correlation_id'] = corrid
        msg.properties['reply_to'] = callback_queue
        
        self.safePublish(channel, msg=msg, exchange='', routing_key=workQueue)
                
        while self._response[corrid] is None:
            try:
                channel.wait()
                log.info('RPC request on %s' % workQueue)
            except (socket.error, IOError) as e:
                log.warn('Socket error: {}.  Will try to reconnect.'.format(e))
                conn = self.connect(re_establish=True)
                channel, callback_queue = setup_channel(callback_queue)
                channel.basic_consume(callback=on_response, no_ack=True, queue=callback_queue)
        
        return self._response.pop(corrid)
    
    # Only waits for a message on a specific queue and then publishes the message
    def rpcRecvRequest(self, workQueue, callback):
        conn = self.connect()
                    
        def on_request(channel, msg):
            msg.channel = channel
            res = callback(msg.body)
            resMsg = amqp.Message(jsonencode(res))
            resMsg.properties['correlation_id'] = msg.properties['correlation_id']
            
            self.safePublish(msg.channel, msg=resMsg, exchange='', routing_key=msg.properties['reply_to'])
            msg.channel.basic_ack(delivery_tag=msg.delivery_tag)
            
        def setup_channel():
            channel = self.safeChannel(conn)
            channel.queue_declare(queue=workQueue)
                
            channel.basic_qos(prefetch_size=0, prefetch_count=1, a_global=False)
            channel.basic_consume(callback=partial(on_request, channel), queue=workQueue)
            
            return channel
            
        channel = setup_channel()
            
        log.info('RPC worker waiting on %s' % workQueue)
        while True:
            try:
                channel.wait()
            except (socket.error, IOError) as e:
                log.warn('Socket error: {}.  Will try to reconnect.'.format(e))
                conn = self.connect(re_establish=True)
                channel = setup_channel()
                        
    def exchangeExists(self, name):    
        exists = True
        inUse = False
        
        conn = self.connect()
        channel = self.safeChannel(conn)
        
        try:
            channel.exchange_delete(exchange=name, if_unused=True)
        except Exception as e:
            if e[0] == 404:
                exists = False
            if e[0] == 406:
                inUse = True
            
        return exists and inUse
            
class RealtimeNamespace(BaseNamespace):

    def initialize(self):
        self._channels = {}  # _channels[exchange] = greenlet
        self._channel_manager = ChannelManager(shareConnection=False)

    def disconnect(self, *args, **kwargs):
        for name in self._channels.keys():
            self._unsubscribe(name)
        super(RealtimeNamespace, self).disconnect(*args, **kwargs)

    def on_subscribe(self, name):
        self._subscribe(name)

    def on_unsubscribe(self, name):
        self._unsubscribe(name)

    def on_publish(self, name, payload):
        jsondict = jsondecode(payload)
        self._channel_manager.publish(str(name), jsondict)

    def _subscribe(self, name):
        greenlet = gevent.spawn_link_exception(self._relay, name)
        self._channels[name] = greenlet
        
    def _unsubscribe(self, name):
        if name not in self._channels: return
        greenlet = self._channels.pop(name)
        greenlet.kill()
    
    def _relay(self, exchange):
        
        def callback(msg):
            self.emit('message:' + exchange, dict(
                    channel=exchange,
                    data=jsondecode(msg.body)))
        
        self._channel_manager.subscribe(exchange, callback) 
                    
#this is a little syntax sugar for debugging pubsub
class Channel():
    manager = None
    channelname = None
    
    def __init__(self, name):
        self.manager = ChannelManager(shareConnection=False)
        self.channelname = name
        
    def publish(self, **kwargs):
        self.manager.publish(self.channelname + "/", kwargs)
    
    def listen(self):
        
        def callback(msg):
            print jsondecode(msg.body)
        
        self.manager.subscribe(self.channelname + "/", callback)
        
# A logging handler that sends messages via pubsub
class PubSubHandler(logging.Handler):
    
    _channel = None
    _cm = None
    
    def __init__(self, channel='logging/'):
        super(PubSubHandler, self).__init__()
        self._channel = channel
        
        # This might be running in a greenlet, so do not share connection
        self._cm = ChannelManager(shareConnection=False)
        
    def emit(self, msg):
        self._cm.publish(self._channel, {'ts': msg.created, 'file': msg.filename, 'level': msg.levelname, 'msg': msg.msg})
         
