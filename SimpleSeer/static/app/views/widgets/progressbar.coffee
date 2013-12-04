[ SubView, Template] = [
  require("views/subview"),
  require("./templates/progressbar")
]

module.exports = class ProgressBar extends SubView
  template: Template
  selected: null
  i: 0
  count: 0
  frames: []

  # TODO: Move to YAML
  key: 'id'

  receive: (data) =>
    @frames = data
    @count = @frames.length
    @_checkI()
    @render()

  select: (params) =>
    if params and params[@key]?
      @selected = params[@key]
      @_checkI()
      @render()

  getRenderData: =>
    i: @i + 1
    count: @count

  _checkI: =>
    if @selected != null
      for o,i in @frames
        if o.get('id') is @selected
          @i = i
          break

  afterRender: =>
    @$el.find('.fill').css('width', String(((@i + 1) / @count * 100)) + "%")