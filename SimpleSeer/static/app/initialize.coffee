application = require 'application'
Router = require 'lib/router'

$ ->
  $.getJSON '/settings', (data) ->
    _.templateSettings = {interpolate : /\{\{(.+?)\}\}/g}

    window.SimpleSeer = application
    #TODO: bind initalize events
    application._init(data.settings)
    application.initialize()
    # Instantiate the router.
    application.router = new Router()
    Backbone.history.start()
    
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
