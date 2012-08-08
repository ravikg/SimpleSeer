# The application bootstrapper.
module.exports = SeerApplication =
  initialize: ->
    if @settings.mongo.is_slave
      $(".notebook").hide()
			
    if !@settings.template_paths?
      @settings.template_paths = {}
    ViewHelper = require 'lib/view_helper'
    HomeView = require 'views/home_view'
    #FramelistView = require 'views/framelist_view'
    FrameDetailView = require 'views/framedetail_view'
    #FrameSetView = require 'views/frameset_view'
    Router = require 'lib/router'
    Inspections = require 'collections/inspections'
    Measurements = require 'collections/measurements'
    Frames = require 'collections/frames'
    OLAPs = require 'collections/OLAPs'
    FrameSets = require 'collections/framesets'
    Pallette = require 'lib/ui_helper'
    Frame = require "../models/frame"
    @pallette = new Pallette()
    @subscriptions = {}
    @timeOffset = (new Date()).getTimezoneOffset() * 60 * 1000
    @filters = require 'views/filters/init'
		
    if !@.isMobile
      @.socket = io.connect '/rt'
      @.socket.on 'timeout', ->
	    #alert 'websocket timeout'
      @.socket.on 'connect', ->
	    #alert 'websocket connect'
      @.socket.on 'error', ->
	    #alert 'websocket  error'
      @.socket.on 'disconnect', ->
	    #alert 'websocket disconnect'
      #@.socket.on 'message', (msg) ->
	    #console.log 'Got message', msg
      @.socket.on "message:alert/", window.SimpleSeer._serveralert
      @.socket.emit 'subscribe', 'alert/'
    @inspections = new Inspections()
    @inspections.fetch()
    @charts = new OLAPs()
    @measurements = new Measurements()
    @measurements.fetch()
    @frames = new Frames()
    @framesets = new FrameSets()
    TabContainer = require "views/tabcontainer_view"
    @framelistView = new TabContainer({model:Frame,tabs:'tabs'})

    #@lastframes = new Frames()

    @homeView = new HomeView()
    #@framelistView = new FramelistView()

    # set up the client name
    $('#client-name').html window.SimpleSeer.settings.ui_pagename || ""

    # set up the timeout message dialog
    $('#lost_connection').dialog
      autoOpen: false
      modal: true
      buttons:
        Ok: ->
          $( this ).dialog( "close" )

    # Instantiate the router
    @router = new Router()
    # Freeze the object
    Object.freeze? this

  _serveralert: (msg) ->
    window.SimpleSeer.alert(msg['data']['message'], msg['data']['severity'])

  isLoading: =>
    !$('#loadThrob :hidden').length
    
  throbber:
    _cb:[]
    load: (message='Loading...',cb=[]) ->
      $('#throbber').show()
      $('#throbber .message').html(message)
      for o in cb
        @callback(o)
      return
    clear: ->
      $('#throbber').hide()
      for o in @_cb
        o()
      @_cb = []
      return
    callback: (cb) ->
      if Application.isLoading()
        cb()
      else
        @_cb.push cb
      return

  alert: (message, alert_type) ->
    _anchor = @settings.ui_alert_anchor || '#messages'
    _set = true
    if alert_type == 'clear'
      moo = _anchor+" > .alert"
      $(moo).hide 'slow', -> $(@).remove()
    else if alert_type == "redirect"
      window.SimpleSeer.router.navigate(message, true)
    else
      $(".alert-"+alert_type).each (e,v)->
        if v.innerHTML == message
          _set = false
      if _set
        console.log message
        div = $("<div>",
          style: "display: none",
          class: "alert alert-"+alert_type
        ).html message
        $(_anchor).append div
        div.show('normal')


  isMobile:
    /android.+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i.test(navigator.userAgent || navigator.vendor || window.opera) or /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(di|rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test((navigator.userAgent || navigator.vendor || window.opera).substr(0, 4))