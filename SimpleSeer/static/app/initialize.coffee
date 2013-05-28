application = require 'application'
Router = require 'lib/router'

$ ->
  loadUI = ->
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

  reject = (close=true, message="") ->
    $.reject
      reject:
        all:true
      display: ["firefox", "chrome", "gcf", "msie"]
      #closeCookie: true
      paragraph1: message
      paragraph2: ""
      close: close
      beforeClose: loadUI

  b = $.browser
  if application.browser[b.name]?
    if application.browser[b.name]['warn']? and application.browser[b.name]['warn'] > b.versionNumber
      reject(true, "Your browser is not supported by this application and should be upgraded.")
    else if application.browser[b.name]['error']? and application.browser[b.name]['error'] > b.versionNumber
      reject(false, "Your browser is not supported by this application and needs to be updated.")
    else
      loadUI()
  else
    loadUI()
  

