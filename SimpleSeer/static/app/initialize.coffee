application = require 'application'
Router = require 'lib/router'

$ ->
  b = $.browser
  load = true
  if application.browser[b.name]?
    if application.browser[b.name]['warn']? and application.browser[b.name]['warn'] > b.versionNumber
        alert 'Your current browser may have difficulty display portions of this application.  Please upgrade for full support.'
    if application.browser[b.name]['error']? and application.browser[b.name]['error'] > b.versionNumber
        alert 'Your current browser is not supported.  Please upgrade to access this application.'
        load = false
  if load
    $.getJSON '/settings', (data) ->
      _.templateSettings = {interpolate : /\{\{(.+?)\}\}/g}
  
      window.SimpleSeer = application
      application._init(data.settings)
  
        # Instantiate the router.
      application.router = new Router()
        # Load cloud libs if applicable & available
      application.cloud = false
      try
        if data.settings.in_cloud
          application.cloud = require 'cloud'
          application.cloud.initialize()
      catch error
        #cloud not available
      application._preinitialize()
      application.initialize()
      Backbone.history.start()
      # Freeze the object
      #Object.freeze? application
