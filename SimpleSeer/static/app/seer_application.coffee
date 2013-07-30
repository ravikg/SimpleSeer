$.getScript("plugins.js")

# SeerApplication is the basic foundation
# for a deployment instance of SimpleSeer.
# Each deployment will extend this definition
# to provide additional functionality.

module.exports = SeerApplication =
  settings: {}
  collections: {}

  _init: (settings) ->
    document.title = settings.title || ""
    # Change MenuBar.clientName;

    if window.WebSocket?
      @socket = io.connect '/rt'
      @socket.on 'connect', -> return
      @socket.on 'timeout', -> console.error 'websocket timeout'
      @socket.on 'error', -> console.error 'websocket error'
      @socket.on 'disconnect', -> console.error 'websocket disconnect'
