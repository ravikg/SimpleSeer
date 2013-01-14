require 'lib/slide_replace'
application = require 'application'
#Frame = require "../models/frame"
#FrameDetailView = require "views/framedetail_view"
#FramelistView = require "views/framelist_view"
#TabContainer = require "core/views/tabcontainer_view"

module.exports = class SeerRouter extends Backbone.Router
  routes: application.settings['ui_routes'] || {"":"home", "frames": "framelist", "frame/:id": "frame"}

  initialize: () =>
    application.pages
    #loop through paths to draw link menu
  
  home: ->
    return ""
