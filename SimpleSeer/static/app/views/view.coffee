require '../lib/view_helper'
application = require '../application'

Backbone = if describe? then require('backbone') else window.Backbone

# Base class for all views.
module.exports = class View extends Backbone.View
  subviews: null
  context:null
  
  initialize: (options={}) =>
    super()
    if options.context?
      @context = options.context
    @subviews = {}

  template: =>
    return

  getRenderData: =>
    return

  render: =>
    if @context
      for path in @context
        application.loadMenuItem(path)
    @$el.html @template @getRenderData()
    @renderSubviews()
    @afterRender()
    this

  afterRender: =>
    return

  renderSubviews: =>
    for name, subview of @subviews
      subview.render()

  addSubview: (name, viewClass, selector, options) =>
    options = options or {}
    _.extend options,
      parent:@
      selector:selector
    @subviews[name] = new viewClass(options)
    
  clearSubviews: =>
    for name, subview of @subviews
      if subview.clearSubviews
        subview.clearSubviews()
      subview.remove()
    @subviews = {}
