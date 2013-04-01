SubView = require 'views/core/subview'
application = require 'application'
template = require './templates/frameViewer'
Frame = require 'models/frame'

module.exports = class frameViewer extends SubView
  className:"frameViewer"
  tagName:"div"
  template:template
  realtime:true
  useThumb: false
    
  initialize: =>
    @url = ''
    super()
    if @options.usethumb?
      @useThumb = @options.usethumb
    #todo: make camera dependent?
    if @realtime == true
      @subscribe()
    @addCustomEvent("resize", => @setSize())
    $(window).resize( => @setSize())

  subscribe: =>
    if application.socket
      if !application.subscriptions["frame/"]?
        application.subscriptions["frame/"] = application.socket.emit 'subscribe', "frame/"
      application.socket.on "message:frame/", @receive    

  loaderToggle:(img)=>
    @$el.find('.fillImage:visible').css("display", "none")
    ci = $(img.target)
    ci.css("display","inline-block")
    @setSize(ci)

  setSize:(ci=@$el.find(".fillImage:visible")) =>
    ci.css("margin-top", ((@$el.find(".fillImageCont").height() / 2) - (ci.height() / 2) + "px"))    

  receive:(frame)=>
    if !(frame instanceof Frame)
      @frame = new Frame frame.data
    else
      @frame = frame
    if @options.camera? and @frame.get("camera") != @options.camera
      return
    @url = "/grid/#{if @useThumb then "thumbnail_file" else "imgfile"}/#{@frame.get("id")}"
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
    application.modal.onSuccess()
    return @
  
  getRenderData: =>
    url:@url
  
  onUpdate: (frame) =>
    @frame = frame
    @render()

  reflow: =>
    @setSize()