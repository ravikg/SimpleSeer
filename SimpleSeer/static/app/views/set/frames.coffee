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
  skip: 0
  limit: 40
  clearOnFetch: false

  # TODO: Put in YAML
  type: "Assembly"
  key: 'tpm'

  initialize: (options) =>
    @collection = new FilterCollection([], {model: Model,'viewid':'5089a6d31d41c855e4628fb0'})
    Application.subscribe 'frameupdate/', @update
    @collection.setParam 'limit', @limit
    @collection.on "reset", @receive
    @collection.fetch()
    super(options)

  events: =>
    'click [data-widget=SideBar] .header': @_slide

  receive: (models) =>
    for model in models
      if model.get('metadata')['type'] is @type
        @frames.push(model)

    for o,i of @subviews
      if @subviews[o]?.receive?
        @subviews[o].receive(@frames)

      if models.length is 0
        @subviews[o].full = true

    frame = @_getFrame(@frames)
    if frame
      @$el.find('.spacer').attr('data-tolstate', frame.get('metadata').tolstate)

  update: (data) =>
    if data
      for o,i of @subviews
        if @subviews[o]?.update?
          @subviews[o].update(data)

  select:(query) =>
    if query.params and query.params[@key]?
      @selected = query.params[@key]
    for i,o of @subviews
      if o.select?
        o.select(query.params)

    frame = @_getFrame(@frames)
    if frame
      @$el.find('.spacer').attr('data-tolstate', frame.get('metadata').tolstate)

  load: =>
    @skip += @limit
    @collection.setParam 'skip', @skip
    #@collection.setParam 'clearOnFetch', @clearOnFetch
    @collection.fetch()

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