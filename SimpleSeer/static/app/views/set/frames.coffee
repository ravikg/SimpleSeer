[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/frames"),
  require("models/frame")
]

module.exports = class FramesView extends SubView
  template: Template
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

    if @subviews['template-sidebar']?
      @subviews['template-sidebar'].receive(@frames)

    if @subviews['template-metadata']?
      @subviews['template-metadata'].receive(@frames)


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