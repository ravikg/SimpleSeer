module.exports = class View extends Backbone.View

  initialize: (options={}) =>
    super()

    @subviews = {}
    @options = {}
    if options?
      # Backbone doesn't strap this
      # automatically anymore.
      @options = options

    if @options.parent?
      @options.tab = @_findTabParent()

    if @.constructor?
      # Add the 'data-widget="Constructor"'
      # property for ease of stylesheets.
      ctor = String(@.constructor)
      ptn = ctor.match(/function (.*)\(\)/)
      if ptn[1]? then @$el.attr("data-widget", ptn[1])

  _findTabParent: =>
    return {}     

  template: => return

  getRenderData: => return
  
  afterRender: => return

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

  render: =>
    @_bindKeys()
    @$el.html @template @getRenderData()
    @scrapeTemplates()
    @renderSubviews()
    @afterRender()
    return @

  remove: =>
    @clearSubviews()
    @$el.off().unbind().remove()
    super()

  renderSubviews: =>
    for name, subview of @subviews
      subview.render()

  reflow: =>
    for i,o of @subviews
      o.reflow()
    return

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
        viewClass = require placeholder.data("subview")
        options = placeholder.data("options") || {}
        @addSubview("template-#{Number(new Date())}", viewClass, div, options)
        placeholder.removeAttr("data-options")
        placeholder.removeAttr("data-subview")

  visible: =>
    return @$el.is(":visible")