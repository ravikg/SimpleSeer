[ SubView, Template] = [
  require("views/subview"),
  require("./templates/bottombar")
]

module.exports = class ProgressBar extends SubView
  template: Template
  selected: null
  count: 0
  index: 1
  frames: []
  key: 'id'

  receive: (data) =>
    @frames = data
    @count = @frames.length
    @render()

  select: (params) =>
    if params and params[@key]?
      @selected = params[@key]
      @render()

  getRenderData: =>
    data: @selected