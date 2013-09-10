[Application, Template, SubView, FilterCollection, Frame] = [
  require('application'),
  require('./templates/imageList'),
  require('views/core/subview'),
  require("collections/core/filtercollection"),
  require("models/frame")
]

module.exports = class ImageList extends SubView
  template: Template
    
  initialize: =>
    super()
    
    options = @options.parent.options.widget
    @blackList = {fields:[], metadata:[]}
    if options.blackList
      if options.blackList.fields
        @blackList.fields = options.blackList.fields
      if options.blackList.metadata
        @blackList.metadata = options.blackList.metadata
        
    bindFilter = Application.context[@options.parent.dashboard.options.parent.options.context].filtercollection
    
    @filtercollection = new FilterCollection([],{bindFilter:bindFilter,model:Frame,clearOnFetch:false})
    @filtercollection.setParam('limit', @options.parent.options.widget.custom_limit)
    @filtercollection.setParam('skip', 0)
    @filtercollection.subscribePath = 'frame'
    @filtercollection.subscribe('', @receive)    
    @filtercollection.on("reset", @render)
    @filtercollection.fetch()
    
    @on("page", @loadMore)
    return @

  loadMore:(e) =>
    if @filtercollection.lastavail == 20 
      @filtercollection.setParam('skip', (@filtercollection.getParam('skip') + @filtercollection._defaults.limit))
      @filtercollection.fetch()
    return
    
  addObjs: =>
    @render()
    
  receive: (data) =>
    @filtercollection.add data.data, {at:0}
    @render()

  getRenderData: =>
    'blackList': @blackList
    'records': @filtercollection.models

