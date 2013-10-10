[Application, ImageList] = [
  require('application'),
  require("views/widgets/imageList")
]

module.exports = class ImageListCapture extends ImageList

  keyBindings:
    "shift+13": "capture"

  initialize: =>
    super()
    @socketSubscribe("frame/", @hideModal)
    return @
    
  hideModal:(frame) =>
    SimpleSeer.router.navigate("#explore/part/#{frame.data.id}", {trigger: true})

  capture: =>
    Application.modal.show({'message':'<p class="large center">Analyzing Part</p>', 'throbber':true})
    message = {command: "capture"}
    Application.socket.emit('publish', 'command/', JSON.stringify(message))