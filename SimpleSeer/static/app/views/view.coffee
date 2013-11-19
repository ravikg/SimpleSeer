module.exports = class View extends Backbone.View

  #keyEvents: =>
  #  {"ctrl + e": "fn"}

  initialize: (options={}) =>
    super()
    @subviews = {}
    @options = {}
    @_keyBindings = []
    @keyEvents = {}

    # Backbone doesn't strap this automatically anymore.
    if options?
      @options = options

    # Add the 'data-widget="Constructor"' attr for stylesheets.
    if @.constructor?
      ctor = String(@.constructor)
      ptn = ctor.match(/function (.*)\(\)/)
      if ptn[1]? then @$el.attr("data-widget", ptn[1])

  getTabParent:(item=@) =>
    if item instanceof require("views/widgets/tabs")
      return item
    else if item.options.parent?
      return @getTabParent(item.options.parent)
    else
      return undefined

  template: => return

  getRenderData: => return
  
  afterRender: => return

  delegateKeyEvents:(events=@keyEvents) =>
    if events instanceof Function
      events = events()
    for key, value of events
      @_keyBindings.push(KeyboardJS.on(key, @[value]))
      
  undelegateKeyEvents: =>
    for binding in @_keyBindings
      binding.clear()

  render: =>
    @$el.html @template( @getRenderData() )
    @scrapeTemplates()
    @renderSubviews()
    @delegateKeyEvents()
    @afterRender()
    return @

  remove: =>
    @clearSubviews()
    @undelegateKeyEvents()
    @undelegateEvents()
    @$el.off().unbind().remove()
    super()

  renderSubviews: =>
    for name, subview of @subviews
      subview.render()

  reflow: =>
    for i,o of @subviews
      o.reflow()
    return

  select:(params) =>
    for key, subview of @subviews
      subview.select?(params)

  unselect:() =>
    for key, subview of @subviews
      subview.unselect?()

  # Adds a subview to the current view.
  #
  # Subviews:
  # - Get rendered when the parent view is rendered
  # - Get destroyed when parent view is destroyed
  # - Can have subviews of their own
  # - All actions are recursive to children
  #
  # Arguments:
  # - name:       The name for the subview.  This is used as the key in `@view.subViews`
  # - viewClass:  The view library.  This should be the result of a something such as `viewClass = require 'views/my_view'`
  # - selector:   A reference to the element the subView will be rendered.  Valid values are `#my-div-id` or a DOM node reference.  Anything valid in the following statement: `$(selector).html`.  When the widget is rendered, it destroys all content within selector.
  # - options:
  #     - append: A string reference to an DOM element ID.  If append is passed in, instead of the widget destroying all content inside of `selector` it appends a div with the id of `append` into the `selector`.  This way multiple subviews can be in the same container.
  #     - Any other items passed in will be available in the subview as `@options.myItem` where `myItem` is the key of options here.
  #
  addSubview: (name, viewClass, selector, options) =>
    options = options or {}
    _.extend(options, {parent: @, selector: selector})
    @subviews[name] = new viewClass(options)

  clearSubviews: =>
    for name, subview of @subviews
      if !_.isEmpty subview
        subview.clearSubviews()
      subview.remove()
      subview.unbind()
    @subviews = {}

  scrapeTemplates: =>
    templates = @$("[data-subview]")
    if templates.length
      for div in templates
        placeholder = $(div)
        id = placeholder.data("id")
        
        if @subviews["template-#{id}"]?
          @subviews["template-#{id}"].remove()
          delete @subviews["template-#{id}"]

        viewClass = require placeholder.data("subview")
        options = placeholder.data("options") || {}
        @addSubview("template-#{id}", viewClass, div, options)
        placeholder.removeAttr("data-options")
        placeholder.removeAttr("data-subview")

  visible: =>
    return @$el.is(":visible")