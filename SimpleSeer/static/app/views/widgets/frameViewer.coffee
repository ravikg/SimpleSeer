SubView = require '../subview'
application = require '../../application'
template = require './templates/frameViewer'

module.exports = class frameViewer extends SubView
  className:"frameViewer"
  tagName:"div"
  template:template
  
  initialize: =>
    super()
    application.socket.on "message:frame/", @capEvent
    application.socket.emit 'subscribe', 'frame/'

  capEvent:(frame)=>
    img = new Image()
    img.src = frame.data.imgfile
    $(img).load =>
      @url = frame.data.imgfile
      li = $(@imgs[@imgcurr])
      @imgcurr=(@imgcurr+1)%@imglen
      ci = $(@imgs[@imgcurr])
      ci.attr('src',@url)
      ci.css("display","inline-block")
      li.css("display", "none")
      #@$el.find('img').attr('src',@url)
    
  render:=>
    super()
    @imgs = @$el.find('img')
    @imglen = @imgs.length
    @imgcurr = 0
    return @
  
  getRenderData: =>
    url:@url
  
  onUpdate: (frame) =>
    @frame = frame
    @render()
