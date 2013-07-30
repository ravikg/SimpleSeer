[Application, Router] = [
  require("application"),
  require("scripts/router")
]

# Initialize is responsible for fetching
# the application settings and setting up
# the interface.

$ ->
  b = $.browser
  m = "Your browser is not supported by this application and should be upgraded."
  loadInterface()
  ###if Application.browser[b.name]?
    if Application.browser[b.name]['warn']? and Application.browser[b.name]['warn'] > b.versionNumber
      reject(true, m)
    else if Application.browser[b.name]['error']? and Application.browser[b.name]['error'] > b.versionNumber
      reject(false, m)
    else
      loadInterface()
  else
    loadInterface()###

loadInterface = =>
  $.getJSON "/settings", (data) ->
    window.SimpleSeer = Application
    Application._init(data.settings)
    Application.router = new Router
    Application.cloud = false
    if data.settings?.in_cloud?
      Application.cloud = require 'cloud'
      Application.cloud.initialize()
    Application.initialize()
    Backbone.history.start()

rejectUser = (close=true, message="")=>
  $.reject {
    reject: { all: true }
    display: ["firefox", "chrome", "gcf", "msie"]
    paragraph1: message
    paragraph2: ""
    close: close
    beforeClose: loadInterface
    imagePath: '/img/seer/'
  }
