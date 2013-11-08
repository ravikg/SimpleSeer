$ ->
  $.getJSON '/settings', (data) ->
    settings = data.settings

    $.getJSON '/_auth', (auth) ->
      window.Application = Application = require('application')
      Application.initialize(data.settings)      
      Backbone.history.start()