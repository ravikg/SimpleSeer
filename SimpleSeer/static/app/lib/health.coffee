module.exports = class HealthCheck

  initialize: =>
    @panicCount = 0
    @ping()

    host = window.location.host.split(":")
    hostname = Application.settings.hostname || ''
    locals = ["127.0.0.1", "localhost"]
    if host[0] in locals
      Application.subscribe("#{hostname}_heartbeat_ping/", @pong)

  ping: ->
    onSuccess = =>
      @panicCount = 0
      setTimeout(@ping, 10000)
      PanicMode?(false)
      
    onError = =>
      @panicCount++
      if( @panicCount >= 2 ) then PanicMode?()
      setTimeout(@ping, 10000) 

    $.getJSON("/ping", (onSuccess)).fail(onError)
    return
    
  pong:(msg) =>
    data = msg['data']
    timestamp = new moment().unix()
    data['name'] = 'chrome'
    data['status'] = true
    data['message'] = 'pong'
    data['timestamp_pong'] = timestamp
    @socket['namespaces']['/rt'].emit('publish', 'heartbeat_pong/', JSON.stringify(data))
