[Application, Template, SubView, FilterCollection,
 Frame, InspectionMap] = [
  require('application'),
  require('./templates/imageList'),
  require('views/core/subview'),
  require("collections/core/filtercollection"),
  require("models/frame"),
  require("views/widgets/inspectionmap")
]

module.exports = class ImageList extends SubView
  template: Template
    
  initialize: =>
    super()
    
    options = @options.parent.options.widget
    @blackList = {fields:[], metadata:[]}
    @blocks = []
    if options.blackList
      if options.blackList.fields
        @blackList.fields = options.blackList.fields
      if options.blackList.metadata
        @blackList.metadata = options.blackList.metadata
    if options.blocks
      @blocks = options.blocks
        
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
    @filtercollection.add(data.data, {at:0})
    @render()
    
  render: =>
    @clearSubviews()
    super()
    
  afterRender: =>
    if "inspections" in @blocks
      for subview in @subviews
        subview.undelegateEvents()
      for frame in @filtercollection.models
        id = frame.attributes.id
        sv = @addSubview("im-#{id}", InspectionMap, "#inspection_#{id}", {model: frame})
        sv.render()      

  getRenderData: =>
    'blackList': @blackList
    'records': @filtercollection.models
    'blocks': @blocks

