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
  subscribePath:"Chart"
  
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
    #if args.realtime
    #  @subscribe()
    @on("remove",@shiftChart)
    @fetch()
    return @

  comparator: (point,point2) =>
    if point2.attributes.x.unix and point.attributes.x.unix
      if point2.attributes.x.unix() > point.attributes.x.unix()
        return -1
      else
        return 1
    else
      if point2.attributes.x > point.attributes.x
        return -1
      else
        return 1
    

  parse: (response) =>
    @raw = response.data
    super(response)
    @subscribe(response.chart)
    clean = @_clean response.data
    return clean

  fetch: (args={}) =>
    @view.showMessage('loading','Loading')
    args.success = @onSuccess
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
    if @view.options.callback?
      @view.options.callback(@view)
    $('.alert_error').remove()
  
  onError: =>
    console.log 'error'
    @view.showMessage('error','Error retrieving data')

  _clean: (data) =>
    refined = []
    for d in data
      point = @_formatChartPoint d
      if point.attributes != {}
        refined.push point
    return refined

  _drawData: =>
    points = []
    for p in @models
      points.push p.attributes
    @view.setData points, @id
    if points.length
      @view.hasData = true
    @shiftStack(true)
    return
  
  _formatChartPoint: (d) =>
    if !@accumulate
      cp = @view.clickPoint
      mo = @view.overPoint
    if !@xAxis.type? or @xAxis.type == ""
      d.d[0] = @_counter++
    else if @xAxis.type == 'datetime'
      d.d[0] = moment.utc(d.d[0])
    if @accumulate
      if @xAxis.type == 'datetime'
        _id = d.d[0].unix()
      else
        _id = d.d[1]
    else
      _id = d.m[2]
    _point =
      marker:{}
      y:d.d[1]
      x:d.d[0]
      raw:d.d
      id:_id
      events:
        mouseOver: @pointEvents.over
        click: @pointEvents.click
    if d.d.length > 2
      #remove y
      y = d.d.shift()
      _point.multipoint = []
      for p in d.d
        _point.multipoint.push @_formatChartPoint {d:[y,p],m:d.m}
        

    #for i,s of @model.metaMap
    #  if s == 'string' && @model.colormap
    #    _point.marker.fillColor = @model.colormap[d.m[i]]
    return _point

  shiftStack: (silent=false)=>
    shifted = 0
    while @_needShift()
      foo = @shift {silent:silent}
      shifted++
    return shifted

  _needShift: (offset=0)=>
    #TODO: remove against, grab from filter
    if @models.length == 0
      return false
    against = new moment().subtract('days',5000)
    if @xAxis.type == "datetime"
      if @.at(0) && @.at(0).attributes.x < against
        return true
    if @models.length - @view.maxPointSize >= offset
      return true
    return false
    
  
  receive: (data) =>
    for o in data.data.m.data
      p = @_formatChartPoint o
      if @inStack(p)
        if @accumulate
          @remove p.x.unix(), {silent: true}
        @add p, {silent: true}
        @view.hasData = true
    @_drawData()
    if @view.hasData && @view.hasMessage
      @view.hideMessage()
    return
    
  inStack:(point) =>
    if @length == 0
      return true
    return point.x >= @at(0).get("x") or @_needShift(-1)
    
  shiftChart: =>
    @view.shiftPoint @id, false    
