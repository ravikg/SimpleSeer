[Collection, OLAP] = [
  require("collections/collection"),
  require("models/olap")
]

module.exports = class OLAPs extends Collection
  url: "/api/chart"
  model: OLAP

  initialize: (args={}) =>
    @paused = false
    @timeframe = 300
    if args.view?
      # Bind view to collection so we know where our widgets live
      @view = args.view
    super(args)

  fetch: (args={}) =>
    if !args.success?
      _.extend(args, {success: @onSuccess})
    super(args)

  onSuccess:(obj, json) =>
    json.sort((a, b) -> (a.renderorder || 100) - (b.renderorder || 101))
    for chart in json
      model = @get(chart.id)
      if !model.view
        if charts[chart.style]
          _id = chart.name
          sv = @view.addSubview(_id, charts[chart.style], '#charts', {append: _id, id: chart.id, model: model})
          sv.render()
        else
          console.error(chart.style + ' is not a valid chart type')
    return