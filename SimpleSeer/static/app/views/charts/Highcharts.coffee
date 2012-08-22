application = require '../../application'
ChartView = require '../chart'
series = require '../../collections/charts/series'


module.exports = class HighchartsLib extends ChartView
  stacked = false
  template: require '../templates/chart'
  initialize: =>
    @lib = 'highcharts'
    super()
    this

  buildChart: () =>
    if @model.attributes.chartid
      @template = ''
      @$el.html ''
      m = @collection.get @model.id
      m.view._c.addSeries @createSeries()
      chart = m.view._c
    else
      _target = @$el.find '.graph-container'
      chart = new Highcharts.Chart
        chart:
          renderTo: _target[0]
          type: @model.attributes.style.toLowerCase()
          height: @model.attributes.height || '150'
        series: [ @createSeries() ]
        xAxis:
          tickInterval: @model.tickerinterval * 1000 || null
          type:
            @model.attributes.xtype || 'linear'
          title:
            text: @model.attributes.xTitle
          labels:
            formatter: -> 
              if this.axis.options.type == 'datetime'
                Highcharts.dateFormat('%m/%d<br>%I:%M:%S', this.value)
              else
                m = application.charts.get @model.id
                if m.attributes.labelmap && m.attributes.labelmap[this.value]
                  return m.attributes.labelmap[this.value]
                else
                  return this.value
        yAxis:
          title:
            text: @model.attributes.yTitle
          min:@model.attributes.minval
          max:@model.attributes.maxval
      chart.id = @id
      if @model.attributes.useLabels
        chart.xAxis[0].setCategories @model.attributes.labelmap
      super chart

  setStackPoints: (d=false) =>
    return
    """
    if @stacked == true || @_c.series.length > 1
      @stacked=true
      @stackPoints = []
      for i,s of @_c.series
        l = s.data.length
        p = s.data[--l]
        if d && d.x > p.x
          p.x = d.x
          s.addPoint(p, false,true)
        @stackPoints[i] = p
    """
  addPoint: (d,redraw=true,shift=false) =>
    super(d)
    """
    if @.stack
      @.stack.add d
    else
      series = @._c.get @.id
      series.addPoint(d,false,shift)
    @setStackPoints(d)
    if redraw
      series.chart.redraw();
    """
  setData: (d) =>
    super(d)
    #@setStackPoints()
    series = @._c.get @.id
    #series.setData([])
    #for _d in d
    #  @.addPoint(_d, false, false)
    #@_c.redraw()
    series.setData(d)
    
  showTooltip: (id) =>
    point = @._c.get id
    if point
      @._c.tooltip.refresh point
    else
      @._c.tooltip.hide()

  hideTooltip: =>
    @._c.tooltip.hide()
    
  alterPoint: (pId, v=0) =>
    super(pId, v)
    p = @._c.get(pId)
    if p
      if v <= 0
        v = ++p.y
      p.update(v)

  incPoint: (d) =>
    #todo: refactor so we dont re-draw chart
    #p = @._c.get d.id
    d.y = 1
    super d
    if @.stack
      @stack.add d
      dd = @.stack.buildData()
      @.setData(dd)
    return

  createSeries: =>
    ###
    new series
      view: @
      accumlate: @model.attributes.accumulate
      xtype: @model.attributes.xtype
      name: @model.attributes.name
      color: @model.attributes.color
    ###
    id:@model.id
    name: @model.attributes.name || ''
    #shadow:false
    color: @model.attributes.color || 'blue'
    marker:
      enabled: true
      radius: 2
    data:[]
    
  isStacked: =>
    return @._c.series.length > 1 ? true : false
