[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/sidebar")
  require("models/frame")
]

module.exports = class SideBar extends SubView
  template: Template
  title: "ASSEMBLIES"
  type: "Assembly"
  key: 'tpm'
  frames: []
  selected: null

  initialize: (options) =>
    @collection = new Backbone.Collection([], {model: Model})
    @collection.url = "api/frame"
    @collection.fetch({'success': @receive})
    super(options)

  receive: (data) =>
    @frames = []
    if data.models
      for model in data.models
        if model.get('metadata')['type'] is @type
          @frames.push(model)
    @render()

  select: (params) =>
    if params and params[@key]?
      @selected = params[@key]
      @afterRender()
      
  events: =>
    'click .header': @_slide
    'click .item': @_select

  _slide: (e) =>
    $(@$el.get(0)).attr 'data-state', (if $(@$el.get(0)).attr('data-state') is 'closed' then 'open' else 'closed')

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
      @$el.find('.item.active').removeClass('active')
      @$el.find(".item[data-value=#{@selected}]:first").addClass('active')



