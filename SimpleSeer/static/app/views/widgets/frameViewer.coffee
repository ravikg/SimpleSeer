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
    @addCustomEvent("resize", =>
      @setSize(@$el.find(".fillImage:visible"))
    )
    $(window).resize(=>
      @setSize(@$el.find(".fillImage:visible"))
    )

  loaderToggle:(img)=>
    @$el.find('.fillImage:visible').css("display", "none")  
    ci = $(img.target)  
    ci.css("display","inline-block")
    @setSize(ci)

  setSize:(ci) =>
    ci.css("margin-top", ((@$el.find(".fillImageCont").height() / 2) - (ci.height() / 2) + "px"))    

  capEvent:(frame)=>
    @url = frame.data.imgfile
    @imgcurr=(@imgcurr+1)%@imglen
    ci = $(@imgs[@imgcurr])
    ci.attr('src',@url)
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