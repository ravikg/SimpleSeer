SubView = require './subview'

#template = require './templates/chart'
view_helper = require '../lib/view_helper'
application = require '../application'
series = require '../collections/charts/series'

module.exports = class ChartView extends SubView
  template: ''
  lastframe: ''
  _counter:0
  #points:{}
  type: ''
  olap: ''
  maxPointSize:0
  isLoading: false
  hasData: false
  hasMessage: false
  
  initialize: =>
    super()
    # TODO: each chart should have mutliple series
    bindFilter = false
    if @options.parent.dashboard
      bindFilter = @options.parent.dashboard.options.parent.filtercollection
      bindFilter.on "add", @linkUpdate
      bindFilter.on "reset", @linkUpdate
    @type = @model.attributes.name.toLowerCase()
    if @model.attributes.maxPointSize?
      @maxPointSize = @model.attributes.maxPointSize
    else
      @maxPointSize = 20
    @points = {}
    @points[@id] = new series
      view: @
      bindFilter:bindFilter
      id: @id
      accumlate: @model.attributes.accumulate
      xtype: @model.attributes.xtype
      name: @model.attributes.name
      color: @model.attributes.color
    #todo: make pointstack an underscore collection in view
    #if @model.attributes.accumulate
    #  _m = @model
    #  @stack = _m.pointStack()
    return @

  linkUpdate: (a,b,c)=>
    for i,o of @points
      o.fetch()
    #series.onSuccess

  #TODO: put these in the _.collection 
  setData: (d, sid) =>
    return d
  addPoint: (d, sid) =>
    return d
  shiftPoint: (sid) =>
    return
  incPoint: (d, sid) =>
    return d
  alterPoint: (d, sid) =>
    return d

  buildChart: (c=false) =>
    if c
      @_c = c
    return
  ###
  afterRender: =>
    if @model.attributes.realtime && application.socket
      application.socket.on "message:Chart/#{@.name}/", @_update
      if !application.subscriptions['Chart/'+@model.attributes.name+'/']
        application.subscriptions['Chart/'+@model.attributes.name+'/'] = application.socket.emit 'subscribe', 'Chart/'+@model.attributes.name+'/'
  ###
  getRenderData: =>
    retVal = @model
    if retVal
      return retVal.attributes
    return false

  update: (frm, to)=>
    for o in @points
      o.fetch()
    return

  setColor:(title, value) =>
    return

  overPoint: (e) =>
    if application.charts._imageLoader
      clearInterval application.charts._imageLoader
    application.charts._imageLoader = setTimeout (->
      application.charts.previewImage e.target.id
    ), 500
    for m in application.charts.models
      if !m.attributes.ticker && m.view
        m.view.showTooltip e.target.id

  clickPoint: (e) =>
    application.charts.addFrame e.point.id
    for m in application.charts.models
      #if point.series.chart.container.parentElement.id != m.id
      if m.view._c.get
        p = m.view._c.get e.point.id
        if p && p.update
          if p.marker && p.marker.radius > 2
            #p.update({ marker: {}},true)
          else
            p.update({ marker: { color: '#BF0B23', radius: 5}},true)
    return false

  ###
  _update: (data) =>
    @_drawData @_clean data.data.m.data
  ###
  showMessage: (type, message)=>
    if type == 'loading'
      @isLoading = true
    @hasMessage = true
    return
    
  hideMessage: =>
    @isLoading = true
    @hasMessage = false
    return
  
  render: =>
    super()
    @buildChart()
    @update()
    return @


