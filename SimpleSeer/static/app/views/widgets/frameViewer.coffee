SubView = require 'views/core/subview'
application = require 'application'
template = require './templates/frameViewer'
Frame = require 'models/frame'

module.exports = class frameViewer extends SubView
  className:"frameViewer"
  tagName:"div"
  template:template
    
  initialize: =>
    @url = ''
    super()
    #todo: make camera dependent?
    if application.socket
      if !application.subscriptions["frame/"]?
        application.subscriptions["frame/"] = application.socket.emit 'subscribe', "frame/"
      application.socket.on "message:frame/", @receive
    @addCustomEvent("resize", => @setSize())
    $(window).resize( => @setSize())

  loaderToggle:(img)=>
    @$el.find('.fillImage:visible').css("display", "none")
    ci = $(img.target)
    ci.css("display","inline-block")
    @setSize(ci)

  setSize:(ci=@$el.find(".fillImage:visible")) =>
    ci.css("margin-top", ((@$el.find(".fillImageCont").height() / 2) - (ci.height() / 2) + "px"))    

  receive:(frame)=>
    if @options.camera? and frame.data.camera != @options.camera
      return
    @frame = new Frame frame.data
    @url = @frame.get('imgfile')
    @imgcurr=(@imgcurr+1)%@imglen
    ci = $(@imgs[@imgcurr])
    ci.attr('src',@url)
    return @frame
    
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