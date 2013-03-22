from pika import BlockingConnection, ConnectionParameters, BasicProperties

from socketio.namespace import BaseNamespace

from .Session import Session
from .base import jsonencode, jsondecode

import logging
log = logging.getLogger(__name__)

class ChannelManager(object):
    
    def __init__(self, context=None):
        self._config = Session()
        self._response = {}
        self._connection = BlockingConnection(ConnectionParameters(host=self._config.rabbitmq))
        
    def __repr__(self):
        return '<ChannelManager>' 
        
    def __del__(self):
        self._connection.close()

    def publish(self, exchange, message):
        channel = self._connection.channel()
        channel.exchange_declare(exchange=exchange, exchange_type='fanout')
        channel.basic_publish(exchange=exchange, routing_key='', body=message)
        print 'Sent on %s' % exchange
        
    def subscribe(self, exchange, callback):
        log.info('Subscribe to %s' % exchange)                     
        channel = self._connection.channel()
        
        channel.exchange_declare(exchange=exchange, exchange_type='fanout')
        result = channel.queue_declare(exclusive=True)
        queue_name = result.method.queue
        
        channel.queue_bind(exchange=exchange, queue=queue_name)
        channel.basic_consume(callback, queue=queue_name, no_ack=True)
        channel.start_consuming()
        
    def rpcSendRequest(self, workQueue, request):
        from random import choice
        
        corrid = ''.join([ choice('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ') for i in range(20) ])
        self._response[corrid] = None
        
        
        def on_response(ch, method, props, body):
            if corrid == props.correlation_id:
                self._response[corrid] = body
                
        channel = self._connection.channel()
        result = channel.queue_declare(exclusive=True)
        callback_queue = result.method.queue
        
        channel.basic_consume(on_response, no_ack=True, queue=callback_queue)
        channel.basic_publish(exchange='', routing_key=workQueue, body=request, properties=BasicProperties(reply_to=callback_queue, correlation_id=corrid, content_type='application/json'))
        
        while self._response[corrid] is None:
            self._connection.process_data_events()
            #print 'response is %s' % response
            
        return self._response.pop(corrid)
    
    def rpcRecvRequest(self, workQueue, callback):
        
        def on_request(ch, method, props, body):
            response = callback(body)
            
            ch.basic_publish(exchange='', routing_key=props.reply_to, body=response, properties=BasicProperties(correlation_id=props.correlation_id))
            ch.basic_ack(delivery_tag=method.delivery_tag)
        
        channel = self._connection.channel()
        channel.queue_declare(queue=workQueue)
            
        channel.basic_qos(prefetch_count=1)
        channel.basic_consume(on_request, queue=workQueue)
        log.info('RPC worker waiting on %s' % workQueue)
        channel.start_consuming()
            
class RealtimeNamespace(BaseNamespace):

    def initialize(self):
        self._channels = {}  # _channels[name] = (socket, greenlet)
        self._channel_manager = ChannelManager()

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
        socket = self._channel_manager.subscribe(name)
        greenlet = gevent.spawn_link_exception(self._relay, name, socket)
        self._channels[name] = (socket, greenlet)
        
    def _unsubscribe(self, name):
        if name not in self._channels: return
        socket, greenlet = self._channels.pop(name)
        greenlet.kill()
        self._channel_manager.unsubscribe(name, socket)

    def _relay(self, name, socket):
        while True:
            channel = socket.recv() # discard the envelope
            message = socket.recv()
            self.emit('message:' + name, dict(
                    channel=channel,
                    data=jsondecode(message)))

#this is a little syntax sugar for debugging pubsub
class Channel(object):
    manager = ''
    channelname = ''
    subsock = ''
    
    def __init__(self, name):
        self.manager = ChannelManager()  #this is a borg, so 
        self.channelname = name
        
    def publish(self, **kwargs):
        self.manager.publish(self.channelname + "/", kwargs)
    
    def listen(self):
        if self.subsock == '':
            self.subsock = self.manager.subscribe(self.channelname + "/")
        
        channel = self.subsock.recv()
        message = self.subsock.recv()
        
        return jsondecode(message)
        
