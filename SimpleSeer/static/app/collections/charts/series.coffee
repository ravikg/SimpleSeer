#Collection = require "../collection"
FilterCollection = require "collections/core/filtercollection"
application = require 'application'
module.exports = class Series extends FilterCollection
  url: ""
  redraw: false
  xAxis:{}
  yAxis:{}
  data:[]
  marker:
    enabled: true
    radius: 2
  pointEvents:
    over:->
    click:->
    out:->
  
  initialize: (models, args={}) =>
    @_counter = 0
    @filterRoot = "Chart"
    @name = args.name || ''
    @id = args.id
    if args.url
      _url = args.url
    else
      _url = "/chart/data/"
    args.url = _url+@id
    @color = args.color || 'blue'
    # Bind view to collection so we know where our widgets live
    if args.view?
      @view = args.view
    @accumulate = args.accumlate || false
    @xAxis.type = args.xtype
    super(models, args)
    @setParam 'sortkey', 'capturetime_epoch'
    @setParam 'sortorder', 1
    args.realtime = true
    if args.realtime
      @subscribe()
    @on("remove",@shiftChart)
    @fetch()
    return @

  comparator: (point) =>
    return point.get('x')

  parse: (response) =>
    super(response)
    @subscribe(response.chart)
    clean = @_clean response.data
    return clean

  fetch: (args={}) =>
    @view.showMessage('loading','Loading...')
    if !args.success?
      args.success = @onSuccess
    if !args.error?
      args.error = @onError
    args['total'] = true
    args['params'] = {skip:~@limit+1,limit:@limit}
    super(args)

  onSuccess: (obj, rawJson) =>
    #TODO: make a better bubble up callback system than this hackery:
    if @view.options.parent.rawCallback?
      @view.options.parent.rawCallback(@raw)
    @view.hasData = false
    @_drawData()
    @view.hideMessage()
    if !@view.hasData
      @view.showMessage('error','No data to display')
    $('.alert_error').remove()
  
  onError: =>
    @view.showMessage('error','Error retrieving data')

  _clean: (data) =>
    refined = []
    for d in data
      refined.push @_formatChartPoint d
    return refined

  _drawData: =>
    @shiftStack(true)
    points = []
    for p in @models
      points.push p.attributes
    @view.setData points, @id
    if points.length
      @view.hasData = true
    return
  
    dd = []
    if reset
      if @.model.accumulate
        dd = @.stack.buildData data
      else
        dd = data
      @.setData dd, true
    else
      for d in data
        if @.model.accumulate
          @.incPoint d
        else
          @.addPoint(d.attributes,true,true)

  _formatChartPoint: (d) =>
    if !@accumulate
      cp = @view.clickPoint
      mo = @view.overPoint
    if !@xAxis.type? or @xAxis.type == ""
      d.d[0] = @_counter++
    else if @xAxis.type == 'datetime'
      d.d[0] = new moment d.d[0]
      d.d[0].subtract('ms', application.timeOffset)
    if @accumulate
      _id = d.d[1]
    else
      _id = d.m[2]
    _point =
      marker:{}
      y:d.d[1]
      x:d.d[0]
      id:_id
      events:
        mouseOver: @pointEvents.over
        click: @pointEvents.click
    #for i,s of @model.metaMap
    #  if s == 'string' && @model.colormap
    #    _point.marker.fillColor = @model.colormap[d.m[i]]
    return _point

  subscribe: (channel=false) =>
    if channel
      application.socket.removeListener "message:Chart/#{@.name}/", @receive
      @name = channel
    if application.socket
      application.socket.on "message:Chart/#{@.name}/", @receive
      if !application.subscriptions["Chart/#{@.name}/"]
        application.subscriptions["Chart/#{@.name}/"] = application.socket.emit 'subscribe', "Chart/#{@.name}/"
  
  shiftStack: (silent=false)=>
    #TODO: remove against, grab from filter
    against = new moment().subtract('days',5000)
    if @xAxis.type == "datetime"
      while @.at(0) && @.at(0).attributes.x < against
        @shift {silent:silent}
    while @models.length - @view.maxPointSize >= silent
      @shift {silent:silent}
    return
  
  receive: (data) =>
    for o in data.data.m.data
      p = @_formatChartPoint o
      @shiftStack()
      @view.addPoint p, @id
      @add @_formatChartPoint o
      @view.hasData = true
    if @view.hasData && @view.hasMessage
      @view.hideMessage()
    return
    
    ###
    dm = @view.model.attributes.dataMap
    mdm = @view.model.attributes.metaMap
    
    m = {}
    d = {}
    for o in data.data.m.data
      for i of o.d
        d[dm[i]] = o.d[i]
      for i of o.m
        m[mdm[i]] = o.m[i]
        
      console.dir d
      console.dir m
    ###
  
  shiftChart: =>
    @view.shiftPoint @id, false    
