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
    @filtercollection = new FilterCollection([],{bindFilter:bindFilter,model:Frame,clearOnFetch:false})
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
    @filtercollection.subscribe('frame',@receive)
    $('#slides').on 'scroll', @loadMore
    return @

  loadMore: (evt)=>
    if ($('#slides').scrollTop() >=  $('#main').height() - $(document).height() + 104) && !application.isLoading() && @$el.is(":visible")
      if @filtercollection.lastavail == 20 
        @$el.find('#loading_message').fadeIn('fast')
        @filtercollection.setParam('skip', (@filtercollection.getParam('skip') + @filtercollection._defaults.limit))
        @filtercollection.fetch({forceRefresh:true})
    
  addObjs: =>
    @render()
    
  receive: (data) =>
    console.dir data.data
    @filtercollection.add data.data
    @render()
    
  getRenderData: =>
    'blackList': @blackList
    'records': @filtercollection.models