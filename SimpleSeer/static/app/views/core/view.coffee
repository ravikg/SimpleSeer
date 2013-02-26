#### views.coffee is the base class for all views
# - - -

# Main application reference 
application = require 'application'

module.exports = class View extends Backbone.View
  subviews: null
  events: {}
  firstRender:true

    
  initialize: (options={}) =>
    super()
    if options.context?
      # Load any context attached to view  
      # For further details, see:  
      # _SeerCloud/_ `models/core/context`  
      # _SimpleSeer/_ `seer_application`
      application.loadContext(options.context)
    @subviews = {}

  # Override in child class.  Returns template handlebars function
  template: =>
    return

  # Override in child class.  Returns context for rendering templates
  getRenderData: =>
    return

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
    callback = =>
      @$el.html @template @getRenderData()
      @renderSubviews()
      @afterRender()
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

  addSubview: (name, viewClass, selector, options) =>
    options = options or {}
    _.extend options,
      parent:@
      selector:selector
    @subviews[name] = new viewClass(options)
    
  # Recursively destroys subviews.  This is done automatically in `@remove`
  clearSubviews: =>
    for name, subview of @subviews
      if subview.clearSubviews
        subview.clearSubviews()
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