[ SubView, Template, Model, FilterCollection ] = [
  require("views/subview"),
  require("./templates/frames"),
  require("models/frame"),
  require("collections/filtercollection")
]

module.exports = class FramesView extends SubView
  template: Template
  frames: []
  selected: null

  # TODO: Put in YAML
  type: "Assembly"
  key: 'tpm'

  initialize: (options) =>
    #@collection = new Backbone.Collection([], {model: Model})
    @collection = new FilterCollection([], {model: Model,'viewid':'5089a6d31d41c855e4628fb0'})
    #@collection.url = "api/frame"
    @collection.on "reset", @receive
    @collection.fetch()
    super(options)

  events: =>
    'click [data-widget=SideBar] .header': @_slide    

  receive: (models) =>
    @frames = []
    for model in models
      #console.log model.get('metadata')
      if model.get('metadata')['type'] is @type
        @frames.push(model)
    #console.log @frames
    for o,i of @subviews
      if @subviews[o]?.receive?
        @subviews[o].receive(@frames)

    frame = @_getFrame(@frames)
    if frame
      @$el.find('.spacer').attr('data-tolstate', frame.get('metadata').tolstate)

  select:(query) =>
    if query.params and query.params[@key]?
      @selected = query.params[@key]
    for i,o of @subviews
      if o.select?
        o.select(query.params)

    frame = @_getFrame(@frames)
    if frame
      @$el.find('.spacer').attr('data-tolstate', frame.get('metadata').tolstate)

  events: =>
    'click [data-widget=SideBar] .header': @_slide

  _slide: (e) =>
    @afterRender()

  _getFrame: (frames) =>
    frame = null
    if @selected
      for o,i in frames
        md = o.get('metadata')
        if String(md[@key]) is String(@selected)
          frame = o
          break
    else
      frame = frames[0]
    return frame

  afterRender: =>
    @$el.find('.content-wrapper').css('left', (if @$el.find('[data-widget=SideBar]').width() then @$el.find('[data-widget=SideBar]').width() + 1 else 0 ))