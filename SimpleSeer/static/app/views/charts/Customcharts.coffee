application = require '../../application'
ChartView = require '../chart'

module.exports = class Customcharts extends ChartView
  template: require '../templates/chart'
  initialize: =>
    #@.$el = $ "<div/>", id: @id
    @lib = 'customchart'
    _m = application.charts.get @id
    @stack = _m.pointStack()
    super()
    this

  buildChart: =>
    super()
    #super new application.charts.customCharts[data.chartInfo.name] data

  addPoint: (d) =>
    #console.log 'add'
    super d
    if @.stack
      @.stack.add d, false
      #@.update()


  incPoint: (d) =>
    #console.log 'inc'
    super d
    #if @.stack
    #  ep = @.stack.add d false
    @.render($('#'+@.anchorId))

    return

  #_formatChartPoint: (d) =>
  #  console.log d.d
  #  super d

  setData: (d,reset=false) =>
    super d
    if reset
      @.stack.stack = []
    if @.stack
      for _d in d
        @.stack.add _d
    #@.update()

  showTooltip: (id) =>
    return

  hideTooltip: =>
    return
   
  alterPoint: (pId, v=0) =>
    super(pId, v)
    #@.alterPoint(pId, v)

