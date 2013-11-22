[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/sidebar")
  require("models/frame")
]

module.exports = class SideBar extends SubView
  template: Template
  frames: []
  selected: null

  # TODO: Put in YAML
  title: "ASSEMBLIES"
  key: 'tpm'

  receive: (data) =>
    @frames = data
    @render()

  select: (params) =>
    if params and params[@key]?
      if @selected != params[@key]
        @selected = params[@key]
        @render()
      
  events: =>
    'click .header': '_slide'
    'click .item': '_select'
    'mouseup .resize': 'reciprocate'

  reciprocate: =>
    @options.parent.reflow()

  _slide: (e) =>
    $(@$el.get(0)).attr 'data-state', (if $(@$el.get(0)).attr('data-state') is 'closed' then 'open' else 'closed')
    setTimeout(@reciprocate,10)

  _select: (e) =>
    @$el.find('.item.active').removeClass('active')
    item = $(e.target).closest('.item')
    item.addClass('active')
    value = item.attr('data-value')
    Application.router.navigate("#tab/data/{\"" + @key + "\":\"" + value + "\"}", {trigger: true})

  getRenderData: =>
    title: @title
    frames: @frames

  afterRender: =>
    if @selected
      @$el.find(".item.active").removeClass('active')
      @$el.find(".item[data-value=#{@selected}]:first").addClass('active')
    else
      @$el.find(".item:first").addClass('active')


