# SeerApplication is the basic foundation
# for a deployment instance of SimpleSeer.
# Each deployment will extend this definition
# to provide additional functionality.

require 'lib/view_helper'
require 'lib/transitions'
$.getScript("plugins.js")

module.exports = SeerApplication =
  settings: {}
  menuItems: {}
  menuBars: {}
  context: {}
  alertStack: []
  inAnim: false
  browser: {}
  loading: true
  _keyCodes:
    'alt':1
    'shift':2
    'ctrl':4

  staticwidgets: [
    {
      id: "seerLogin",
      lib: "core/login",
      menubar: "system-tray",
      params: {icon: "/img/seer/login.png", label: "User", style: "inline"}
    }
  ]

  # Set up the application and include the
  # necessary modules. Configures the page
  # and
  _init: (settings) ->
    @_keyBindings = {}
    $("html").keyup @_keyPress

    @settings = _.extend @settings, settings

    if @settings.mongo.is_slave
      $(".notebook").hide()

    if !@settings.template_paths?
      @settings.template_paths = {}

    @subscriptions = {}
    @timeOffset = (new Date()).getTimezoneOffset() * 60 * 1000

    # Set up the client name.
    $('#client-name').html(window.SimpleSeer.settings.ui_pagename || "")
    document.title = window.SimpleSeer.settings.ui_pagename || ""

    window.panicCount = 0
    
    if window.WebSocket?
      @socket = io.connect '/rt'
      @socket.on 'connect', ->
        @socket.on 'timeout', ->
          console.error 'websocket timeout'
        @socket.on 'error', ->
          console.error 'websocket error'
        @socket.on 'disconnect', ->
          console.error 'websocket disconnect'
      @socket.on "message:alert/", window.SimpleSeer._serveralert
      @socket.emit 'subscribe', 'alert/'

      host = window.location.host.split(":")

      if settings.hostname
        hostname = settings.hostname
      else
        hostname = ''

      if host[0] is "127.0.0.1" or host[0] is "localhost"
        @socket.on 'message:' + hostname + '_heartbeat_ping/', window.SimpleSeer._heartbeat_pong
        @socket.emit 'subscribe', hostname + '_heartbeat_ping/'


    t = require 'views/core/modal'
    @modal = new t()

    tol = require 'collections/tolerance_list'
    @tolerance_list = new tol()
    @tolerance_list.fetch({async:false})

    i = require 'collections/inspections'
    @inspections = new i()
    @inspections.fetch({async:false})

    m = require 'collections/measurements'
    @measurements = new m()
    @measurements.fetch({async:false})
    
    @_pingStatus()

    $("#slides").infiniteScroll
      onScroll:(per) =>
        @getActiveTab().trigger 'scroll', per
      onPage: =>
        @getActiveTab().trigger 'page'


  _preinitialize: ->
    tc = require 'collections/tab_container'
    @tabs = new tc()
    #@loadAdmin()
    @tabs.fetch()

  getActiveTab: ->
    tc = @tabs.where({'name':@activeTab[0]})
    return tc[0].view.subviews[@activeTab[1]]

  loadAdmin:() ->
    TabCon = require "models/core/tab_container"
    SimpleSeer.tabs.push new TabCon
      id: "__admindash__"
      navbar: "left-main"
      path: "admin"
      tabs: [{
        name: "db"
        view: "admin"
        inNavigation: false
      }]

  _keyPress: (e) ->
    key = 0
    if e.altKey
      key += SimpleSeer._keyCodes['alt']
    if e.ctrlKey
      key += SimpleSeer._keyCodes['ctrl']
    if e.shiftKey
      key += SimpleSeer._keyCodes['shift']
    key += "_"+ e.which
    if SimpleSeer._keyBindings[key]
      for i,o of SimpleSeer._keyBindings[key]
        for event in o
          event(e)

  # Sends an alert window to the client
  # with the specified message and severity.
  _serveralert: (msg) ->
    window.SimpleSeer.alert(msg['data']['message'], msg['data']['severity'])

  _heartbeat_pong: (msg)->
    data = msg['data']
    timestamp = new moment().unix()
    data['name'] = 'chrome'
    data['status'] = true
    data['message'] = 'pong'
    data['timestamp_pong'] = timestamp
    @socket['namespaces']['/rt'].emit('publish', 'heartbeat_pong/', JSON.stringify(data))

  # Returns the loading status of the application.
  isLoading: =>
    !$('#modal :hidden').length

  addMenuBar:(target, options) ->
    _lib = require 'views/core/menubar'
    _t = $("#"+target)
    if _t.length > 0
      if !options.id?
        options.id = _.uniqueId()
      @menuBars[options.id] = new _lib(options)
      _t.html @menuBars[options.id].render().el
      return @menuBars[options.id]
  
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
    
    
              
  loadContext:(name) ->
    if !@context[name]?
      _context = require 'models/core/context'
      @context[name] = new _context({name:name})
      #a = @context[name].fetch()
    return @context[name]

  alert:(message, alert_type, pop=false) ->
    switch alert_type
      when "clear"
        $("#messages > .alert").remove()
      when "redirect"
        if message is "@rebuild"
          window.location.reload()
        else
          window.SimpleSeer.router.navigate(message || window.location.hash, true)
      else
        if !message then return false
        _duplicate = false

        #$(".alert-#{alert_type}").each (e,v)->
        #  if ($(v).data("message") == message) then _duplicate = true

        if SimpleSeer.modal.isVisible()
          SimpleSeer.modal.setMinorText(message)
        else
          if _duplicate is false
            popup = $("<div style=\"display: none\">#{message}</div>")
            popup.addClass("alert alert-#{alert_type}").data("message", message).appendTo("#messages")
            closeBtn = $("<div class='closeAlerts'></div>")
            closeBtn.click((e, ui) => $(e.currentTarget).parent().fadeOut(-> $(this).remove())).appendTo(popup)
            popup.fadeIn()

  # Uses a regular expression to determine
  # if the user is on a mobile browser or not.
  isMobile:
    /android.+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i.test(navigator.userAgent || navigator.vendor || window.opera) or /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(di|rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test((navigator.userAgent || navigator.vendor || window.opera).substr(0, 4))
