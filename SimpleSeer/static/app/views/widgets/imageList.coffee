application = require 'application'
template = require './templates/imageList'
SubView = require 'views/core/subview'
FilterCollection = require "collections/core/filtercollection"
Frame = require "models/frame"


module.exports = class imageList extends SubView
  template:template
  initialize: =>
    @blackList = {fields:[], metadata:[]}
    if @options.parent.options.widget.blackList
      if @options.parent.options.widget.blackList.fields
        @blackList.fields = @options.parent.options.widget.blackList.fields
      if @options.parent.options.widget.blackList.metadata
        @blackList.metadata = @options.parent.options.widget.blackList.metadata
    bindFilter = application.context[@options.parent.dashboard.options.parent.options.context].filtercollection
    @filtercollection = new FilterCollection([],{bindFilter:bindFilter,model:Frame})
    @filtercollection.on "reset", @addObjs
    super()

    @filtercollection.setParam 'limit', @options.parent.options.widget.custom_limit 
    @filtercollection.setParam 'skip', 0
    @filtercollection.fetch
      success: () =>
          $('#data-views-controls').show()
          $('#views-contain').addClass('wide scroll')
          $('#views').addClass('wide')
          $('#content').addClass('wide')
    @filtercollection.subscribe('',@receive)
    return @
    
  addObjs: =>
    @render()
    
  getRenderData: =>
    'blackList': @blackList
    'records': @filtercollection.models