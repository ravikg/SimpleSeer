SubView = require 'views/core/subview'
application = require 'application'
template = require './templates/frameViewer'

module.exports = class frameViewer extends SubView
  className:"frameViewer"
  tagName:"div"
  template:template
    
  initialize: =>
    super()
    #todo: make camera dependent?
    application.socket.on "message:frame/", @capEvent
    application.socket.emit 'subscribe', 'frame/'

  loaderToggle:(img)=>
    @$el.find('.fillImage:visible').css("display", "none")
    $(img.srcElement).css("display","inline-block")

  capEvent:(frame)=>
    @url = frame.data.imgfile
    li = $(@imgs[@imgcurr])
    @imgcurr=(@imgcurr+1)%@imglen
    ci = $(@imgs[@imgcurr])
    ci.attr('src',@url)
    #if !ci.onload?
    #  ci.onload = @loaderToggle
    #  #$(this).css("display","inline-block")
    #  #li.css("display", "none")
    return
    img = new Image
    img.onload = =>
      @url = frame.data.imgfile
      li = $(@imgs[@imgcurr])
      @imgcurr=(@imgcurr+1)%@imglen
      ci = $(@imgs[@imgcurr])
      ci.attr('src',@url)
      ci.css("display","inline-block")
      li.css("display", "none")
      delete img
      #@$el.find('img').attr('src',@url)
    img.src = frame.data.imgfile
    return
    
  render:=>
    super()
    @imgs = @$el.find('img')
    for o in @imgs
      o.onload = @loaderToggle

    @imglen = @imgs.length
    @imgcurr = 0
    return @
  
  getRenderData: =>
    url:@url
  
  onUpdate: (frame) =>
    @frame = frame
    @render()
