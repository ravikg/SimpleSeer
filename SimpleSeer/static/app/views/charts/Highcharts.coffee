application = require '../../application'
ChartView = require '../chart'
series = require '../../collections/charts/series'


module.exports = class HighchartsLib extends ChartView
  stacked = false
  template: require '../templates/chart'
  initialize: =>
    @lib = 'highcharts'
    super
    return @

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
        title:
          text: @model.attributes.name
        series: [ @createSeries() ]
        credits:
          enabled: false
        legend:
          enabled: false
        xAxis:
          id:''
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
          id:''
          title:
            text: @model.attributes.yTitle
          min:@model.attributes.minval
          max:@model.attributes.maxval
      chart.id = @id
      if @model.attributes.useLabels
        chart.xAxis[0].setCategories @model.attributes.labelmap
      super chart

  shiftPoint: (sid,redraw=true) =>
    super(sid)
    series = @._c.get sid
    series.data[0].remove(false)
    if redraw
      series.chart.redraw()

  addPoint: (d,sid,redraw=true) =>
    super(d,sid)
    series = @._c.get sid
    series.addPoint(d,false,false)
    if redraw
      series.chart.redraw()

  setData: (d,sid,redraw=true) =>
    super(d,sid)
    series = @._c.get sid
    series.setData(d,redraw)
    
  showTooltip: (id) =>
    point = @._c.get id
    if point
      @._c.tooltip.refresh point
    else
      @._c.tooltip.hide()

  hideTooltip: =>
    @._c.tooltip.hide()
  
  #TODO: update
  alterPoint: (pId, v=0) =>
    super(pId, v)
    p = @._c.get(pId)
    if p
      if v <= 0
        v = ++p.y
      p.update(v)

  #TODO: update
  incPoint: (d) =>
    d.y = 1
    super d
    if @.stack
      @stack.add d
      dd = @.stack.buildData()
      @.setData(dd)
    return

  createSeries: =>
    id:@model.id
    name: @model.attributes.name || ''
    shadow:false
    color: @model.attributes.color || 'blue'
    marker:
      enabled: true
      radius: 2
    data:[]
    
  isStacked: =>
    return @._c.series.length > 1 ? true : false
