# Move Application health check into here

module.exports = class HealthCheck  

  _pingStatus: ->
    onSuccess = =>
      window.panicCount = 0
      setTimeout(SimpleSeer._pingStatus, 10000)
      PanicMode(false)
    onError = =>
      window.panicCount++
      if( window.panicCount >= 2 )
        PanicMode()
      setTimeout(SimpleSeer._pingStatus, 10000) 
    $.getJSON("/ping", (onSuccess)).fail(onError)
    return
    
  _heartbeat_pong: (msg)->
    data = msg['data']
    timestamp = new moment().unix()
    data['name'] = 'chrome'
    data['status'] = true
    data['message'] = 'pong'
    data['timestamp_pong'] = timestamp
    @socket['namespaces']['/rt'].emit('publish', 'heartbeat_pong/', JSON.stringify(data))
