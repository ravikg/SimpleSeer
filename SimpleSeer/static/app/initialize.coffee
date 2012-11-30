application = require 'application'
Router = require 'lib/router'

$ ->
  $.getJSON '/settings', (data) ->
    _.templateSettings = {interpolate : /\{\{(.+?)\}\}/g}

    window.SimpleSeer = application
    application._init(data.settings)
   
    # Load cloud libs if applicable & available
    application.cloud = false
    try
      if data.settings.in_cloud
        application.cloud = require './cloud'
        application.cloud.initialize()
    catch error
      #cloud not available
    application.initialize()
    
    # Instantiate the router.
    application.router = new Router()
    Backbone.history.start()
    
    # Freeze the object
    #Object.freeze? application
