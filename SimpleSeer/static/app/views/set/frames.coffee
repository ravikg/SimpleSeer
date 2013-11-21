[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/frames"),
  require("models/frame")
]

module.exports = class FramesView extends SubView
  template: Template
  frames: []
  selected: null

  # TODO: Put in YAML
  type: "Assembly"
  key: 'tpm'

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

    for o,i of @subviews
      if @subviews[o]?.receive?
        @subviews[o].receive(@frames)


  select: (params) =>
    if params and params[@key]?
      @selected = params[@key]

      for i,o of @subviews
        if o.select?
          o.select(params)

  events: =>
    'click [data-widget=SideBar] .header': @_slide

  _slide: (e) =>
    @afterRender()

  afterRender: =>
    @$el.find('.content-wrapper').css('left', (if @$el.find('[data-widget=SideBar]').width() then @$el.find('[data-widget=SideBar]').width() + 1 else 0 ))