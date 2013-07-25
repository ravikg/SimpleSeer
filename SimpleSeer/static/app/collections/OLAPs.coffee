Collection = require "./collection"
OLAP = require "../models/OLAP"
ChartView = require '../views/chart'
application = require '../application'
charts = require '../views/charts/init'

module.exports = class OLAPs extends Collection
  url: "/api/chart"
  model: OLAP
  paused: false
  timeframe:300

  initialize: (args={}) =>
    # Bind view to collection so we know where our widgets live
    if args.view?
      @view = args.view
    super(args)

  fetch: (args={}) =>
    # Create default success action if none supplied to fetch
    if !args.success?
      _.extend args,
        success: @onSuccess
    super(args)

  # Default success action
  onSuccess: (obj, rawJson) =>
    # Sort charts by render order
    # To be deprecated with grid layout
    rawJson.sort (a,b) ->
      (a.renderorder || 100) - (b.renderorder || 101)
    for rawObj in rawJson
      # Get model
      model = @get rawObj.id
      ################
      # TODO: check if chart has chartid
      #       if chartid, get chart and add series
      #       pass in chart type so highcharts can support line pie stack
      #       http://jsfiddle.net/gh/get/jquery/1.7.2/highslide-software/highcharts.com/tree/master/samples/highcharts/demo/combo/
      if !model.view
        if charts[rawObj.style]
          _id = rawObj.name
          vi = @view.addSubview _id, charts[rawObj.style], '#charts', {append:_id,id:rawObj.id,model:model}
          vi.render()
        else
          console.error rawObj.style + ' is not a valid chart type'
    return
