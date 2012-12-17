require '../lib/view_helper'
application = require '../application'
#context = require '../models/core/context'


Backbone = if describe? then require('backbone') else window.Backbone

# Base class for all views.
module.exports = class View extends Backbone.View
  subviews: null
  
  initialize: (options={}) =>
    super()
    if options.context?
      application.loadContext(options.context)
    @subviews = {}

  template: =>
    return

  getRenderData: =>
    return

  render: =>
    @$el.html @template @getRenderData()
    @renderSubviews()
    @afterRender()
    this

  remove: =>
    @removeSubviews()
    super()

  afterRender: =>
    return

  renderSubviews: =>
    for name, subview of @subviews
      subview.render()

  removeSubviews: =>
    for name, subview of @subviews
      subview.remove()
      subview.unbind()
    @subviews = {}

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
