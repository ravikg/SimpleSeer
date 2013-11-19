[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/sidebar")
  require("models/frame")
]

module.exports = class SideBar extends SubView
  template: Template
  title: "ASSEMBLIES"
  type: "Assembly"
  keys: ["tpm"]
  frames: []

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
    console.log @frames
    @render()

  events: =>
    'click .header': @_slide
    'click .item': @_select

  _slide: (e) =>
    $(@$el.get(0)).attr 'data-state', (if $(@$el.get(0)).attr('data-state') is 'closed' then 'open' else 'closed')

  _select: (e) =>
    console.log e
    $(e.target).closest('.item').addClass('active')

  getRenderData: =>
    title: @title
    frames: @frames
    keys: @keys




