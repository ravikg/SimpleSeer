Collection = require "../collection"
application = require '../../application'

module.exports = class Series extends Collection
  url: ""
  redraw: false
  xAxis:{categories:{}}
  yAxis:{}
  data:[]
  marker:
    enabled: true
    radius: 2
  
  initialize: (args={}) =>
    @name = args.name || ''
    #shadow:false
    @color = args.color || 'blue'
    # Bind view to collection so we know where our widgets live
    if args.view?
      @view = args.view
    @accumulate = args.accumlate || false
    @xAxis.type = args.xtype
    super(args)
    args.realtime = true
    if args.realtime
      @subscribe()
    return @
    
  toJSON: ->
    options = _.clone @options
    # Nest the data points to match the Highcharts options
    options.data = super
    return options

  parse: (response) =>
    return @_clean response.data

  fetch: (args={}) =>
    # Create default success action if none supplied to fetch
    m = @view.options.model

    name = m.attributes.name
    frm = new moment().utc().subtract('s',application.charts.timeframe).valueOf()
    to = false
    if frm and to
      @url = "/chart/"+name+"/since/"+frm+"/before/" + to
    else if frm
      @url = "/chart/"+name+"/since/" + frm
    else
      console.error 'frm and or to required'
      return false

    if !args.success?
      _.extend args,
        success: @onSuccess
    if !args.error?
      _.extend args,
        error: @onError
    super(args)

  onSuccess: (obj, rawJson) =>
    @_drawData()
    $('.alert_error').remove()
  
  onError: =>
    SimpleSeer.alert('Connection lost','error')

  _clean: (data) =>
    refined = []
    for d in data
      refined.push @_formatChartPoint d
    return refined

  _drawData: =>
    data = @models
    points = []
    for p in data
      points.push p.attributes
    @view.setData points
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
    if !@xAxis.type?
      d.d[0] = @_counter++
    else if @xAxis.type == 'datetime'
      d.d[0] = new moment d.d[0]
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
        #click: application.charts.callFrame
        mouseOver: mo
        click: cp
        #unselect: @.unselectPoint #application.charts.removeFrame
    #for i,s of @model.metaMap
    #  if s == 'string' && @model.colormap
    #    _point.marker.fillColor = @model.colormap[d.m[i]]
    return _point

  subscribe: =>
    if application.socket
      application.socket.on "message:Chart/#{@.name}/", @receive
      if !application.subscriptions["Chart/#{@.name}/"]
        application.subscriptions["Chart/#{@.name}/"] = application.socket.emit 'subscribe', "Chart/#{@.name}/"
  
  receive: (data) =>
    for o in data.data.m.data
      o.d[0] = o.d[0] * 1000
      p = @_formatChartPoint o
      @view._c.series[0].addPoint p
    @view._c.redraw()
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


