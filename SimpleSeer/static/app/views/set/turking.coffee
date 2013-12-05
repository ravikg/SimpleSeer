[ SubView, Template, Model, FilterCollection ] = [
  require("views/subview"),
  require("./templates/turking"),
  require("models/frame"),
  require("collections/filtercollection")
]

module.exports = class TurkingView extends SubView
  template: Template
  frames: []
  selected: null
  i: 0
  count: 0
  skip: 0
  limit: 40
  clearOnFetch: false

  key: 'id'

  initialize: (options) =>
    # TODO: MOVE BACK INTO KEYBINDINGS
    KeyboardJS.on('left', @_previous)
    KeyboardJS.on('right', @_next)

    @collection = new FilterCollection([], {model: Model,'viewid':'5089a6d31d41c855e4628fb0'})
    Application.subscribe 'frameupdate/', @update
    @collection.setParam 'limit', @limit
    @collection.on "reset", @receive
    @collection.fetch()
    super(options)

  receive: (models) =>
    for model in models
       @frames.push(model)

    @count = @frames.length

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

  #keyEvents: =>
  #  {"right": "_previous",
  #  "left": "_next"}

  _checkI: =>
    if @selected != null
      for o,i in @frames
        if o.get('id') is @selected
          @i = i
          break

  _next: (e) =>
    @_checkI()
    i = @i + 1
    if i < @count
      @frame = @_getFrame(@frames, i)
      Application.router.setParam(@key, @frame.get('id'))
      @options.parent.select(Application.router.query)
      @i = i

  _previous: (e) =>
    @_checkI()
    i = @i - 1
    if i >= 0
      @frame = @_getFrame(@frames, i)
      Application.router.setParam(@key, @frame.get('id'))
      @options.parent.select(Application.router.query)
      @i = i

  load: =>
    @skip += @limit
    @collection.setParam 'skip', @skip
    @collection.fetch()

  _getFrame: (frames, i=null) =>
    frame = null
    if i != null
      frame = frames[i]
    else if @selected
      for o,i in frames
        if String(o.get(@key)) is String(@selected)
          frame = o
          break
    else
      frame = frames[0]
    return frame

  _toggleFeature: (e) =>
    if @subviews['template-turking']._toggleFeature?
      @subviews['template-turking']._toggleFeature(e)