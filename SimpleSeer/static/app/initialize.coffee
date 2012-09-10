application = require 'application'

$ ->
  $.getJSON '/settings', (data) ->
    _.templateSettings = {interpolate : /\{\{(.+?)\}\}/g}

    alert 'hit'
    window.SimpleSeer = application
    #TODO: bind initalize events
    application._init(data.settings)
    application.initialize()
    Backbone.history.start()
    # Instantiate the router.
    application.router = new Router()
    
    # Freeze the object
    Object.freeze? application




"""
application = require 'application'

$ ->
  $.getJSON '/settings', (data) ->
    _.templateSettings = {interpolate : /\{\{(.+?)\}\}/g}

    _.extend application.prototype, {settings:data.settings}
    window.SimpleSeer = new application()
    window.SimpleSeer.settings = data.settings
    window.SimpleSeer.initialize()
    Backbone.history.start()
"""
