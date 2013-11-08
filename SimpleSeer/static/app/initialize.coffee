$ ->
  $.getJSON '/settings', (data) ->
    settings = data.settings

    $.getJSON '/_auth', (auth) ->
      window.SimpleSeer = Application = require('application')
      Application.initialize(data.settings)      
      Backbone.history.start()