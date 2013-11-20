[ SubView, Template] = [
  require("views/subview"),
  require("./templates/bottombar")
]

module.exports = class BottomBar extends SubView
  template: Template
  selected: null
  frames: []

  # TODO: Move to YAML
  key: 'tpm'

  receive: (data) =>
    @frames = data
    console.log @frames
    if @frames and @frames.length > 0 and !@selected
      md = @frames[0].get('metadata')
      @selected = md[@key]
    @render()

  select: (params) =>
    if params and params[@key]?
      @selected = params[@key]
      @render()

  getRenderData: =>
    console.log @selected
    data: @selected