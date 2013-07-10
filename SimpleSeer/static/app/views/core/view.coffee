#### views.coffee is the base class for all views
# - - -

# Main application reference
application = require 'application'
module.exports = class View extends Backbone.View
  subviews: {}
  events: {}
  #keyBindings:
  #  "alt+ctrl+shift+73":"keyfireTest"
  #  "73":"keyfireTest"
  firstRender:true

  #keyfireTest:(e) =>
  #  console.log "keyfire!"
  #  console.log e

  initialize: (options={}) =>
    super()
    #application._keyBindings


    if @options.context?
      # Load any context attached to view
      # For further details, see:
      # _SeerCloud/_ `models/core/context`
      # _SimpleSeer/_ `seer_application`
      application.loadContext(@options.context)
    #@on "uiFocus", @focus
    @subviews = {}

  _bindKeys: =>
    id = if typeof @id == "function" then @id() else @id

    if id and @keyBindings
      for i,o of @keyBindings
        key = 0
        for _key in i.split("+")
          if _key == "alt" or _key == "ctrl" or _key == "shift"
            key += application._keyCodes[_key]
          else
            key += "_" + _key
        if !application._keyBindings[key]?
          application._keyBindings[key] = {}
        if !application._keyBindings[key][id]?
          application._keyBindings[key][id] = []
        if @[o] not in application._keyBindings[key][id]
          application._keyBindings[key][id].push @[o]

  _setScroll: (el=@$el) =>
    el.infiniteScroll
      onScroll:(per) =>
        console.log "scroll";
        return; @trigger('scroll', per)
      onPage: =>
        console.log "page"
        return; @trigger('page')

  focus:(back=false) =>
    #console.info 'in focus'
    #if !back and !@$el.is(":visible")
    #  @$el.show()
    if application.loading
      #console.log 'loading...'
      if @options.context
        if back
          application.loading = false
        #console.log 'ACTIVATING CONTEXT!', @options.context
        application.context[@options.context].activate()
        back = false
      else
        back = true
      if !back
        for i,o of @subviews
          o.focus()
      else
        if @options.parent?
          @options.parent.focus(true)

  unfocus: =>
    #if @$el.is(":visible")
    #  @$el.hide()
    for i,o of @subviews
      o.unfocus()


  # Override in child class.  Returns template handlebars function
  template: =>
    return

  # Override in child class.  Returns context for rendering templates
  getRenderData: =>
    return

  # Shorthand method for subscribing to a channel on the socket
  socketSubscribe:(channel, handler) =>
    if application.socket
      if !application.subscriptions[channel]?
        application.subscriptions[channel] = application.socket.emit('subscribe', channel)
      application.socket.on("message:#{channel}", handler)

  socketPublish:(channel, data) =>
    application.socket.emit("publish", channel, data)

  #### Transition is way to call a method with a transition in and out.
  # > __callback__ : Function to call between __in__ and __out__ effects
  #
  # Valid translations are:
  # blind, bounce, clip, drop, explode, fade, fold, highlight, puff, pulsate, scale, shake, size, slide, transfer
  # __Example__:
  # effect:
  # &nbsp; callback: @myCallback
  # &nbsp; out:
  # &nbsp; &nbsp; type: 'slide'
  # &nbsp; &nbsp; options: { direction: "right" }
  # &nbsp; &nbsp; speed: 500
  # &nbsp; in:
  # &nbsp; &nbsp; type: 'slide'
  # &nbsp; &nbsp; options: { direction: "left" }
  # &nbsp; &nbsp; speed: 500
  transition: (callback) =>
    @$el.hide @effect.out['type'], @effect.out['options'], @effect.out['speed'], =>
      callback()
      @$el.show @effect.in['type'], @effect.in['options'], @effect.in['speed'], @effect['callback'] || => return


  # Renders view using effects if defined
  render: =>
    @_bindKeys()
    #console.log 'render'
    callback = =>
      @$el.html @template @getRenderData()
      @renderSubviews()
      #@focus()
      #@trigger "uiFocus"
      @afterRender()
      if @firstRender  && (@onScroll? || @onPage?)
        _ele = @$el.find(@scrollElement)
        if _ele.length == 0
          _ele = @$el
        @_setScroll(_ele)
        if @onScroll?
          @on "scroll", @onScroll
        if @onPage?
          @on "page", @onPage
      @firstRender = false

    if @effect? and !@firstRender and @$el.is(":visible")
      @transition(callback)
    else
      callback()
    this

  # Recursively destroys subviews, then destroys itself
  remove: =>
    @clearSubviews()
    super()

  # Override in child class.  Runs after render is fired
  afterRender: =>
    return

  # Renders all subviews.  This is done automatically in `@render`
  renderSubviews: =>
    for name, subview of @subviews
      subview.render()

  # Causes a chain reaction of reflows. Any place using this function
  # needs to call super so that all sub-elements get a trigger as well
  reflow: =>
    for i,o of @subviews
      o.reflow()
    return

  # Adds a subview to the current view.
  #
  # -get rendered when the parent view is rendered
  # -get destroyed when parent view is destroyed
  # -can have subviews of their own
  # -all actions are recursive to children
  #
  # Arguments:
  # -`name`: The name for the subview.  This is used as the key in `@view.subViews`
  # -`viewClass`: The view library.  This should be the result of a something such as `viewClass = require 'views/my_view'`
  # -`selector`: A reference to the element the subView will be rendered.  Valid values are `#my-div-id` or a DOM node reference.  Anything valid in the following statement: `$(selector).html`.  When the widget is rendered, it destroys all content within selector.
  # -`options`:
  #     -`append`: a string reference to an DOM element ID.  If append is passed in, instead of the widget destroying all content inside of `selector` it appends a div with the id of `append` into the `selector`.  This way multiple subviews can be in the same container.
  #     - Any other items passed in will be available in the subview as `@options.myItem` where `myItem` is the key of options here.

  addSubview: (name, viewClass, selector, options) =>
    options = options or {}
    _.extend options,
      parent:@
      selector:selector
    @subviews[name] = new viewClass(options)

  # Recursively destroys subviews.  This is done automatically in `@remove`
  clearSubviews: =>
    for name, subview of @subviews
      subview.remove()
      subview.unbind()
    @subviews = {}

  customEvent: (event) =>
    @events[event]?()
    for name, subview of @subviews
      subview.customEvent(event)
    return

  addCustomEvent: (name, callback) =>
    @events[name] = callback
    return
