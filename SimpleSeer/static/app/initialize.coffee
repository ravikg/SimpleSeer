application = require 'application'
Router = require 'lib/router'

$ ->
  $.getJSON '/settings', (data) ->
    _.templateSettings = {interpolate : /\{\{(.+?)\}\}/g}

    window.SimpleSeer = application
    #TODO: bind initalize events
    application._init(data.settings)
    application.initialize()
    try
      require './cloud'
    catch error
      #cloud not available
    
    # Instantiate the router.
    application.router = new Router()
    Backbone.history.start()
    
    # Freeze the object
    Object.freeze? application
