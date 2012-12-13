SubView = require '../subview'
application = require '../../application'
template = require './templates/menuitem'

module.exports = class menuItem extends SubView
  icon:""			        # filename of icon
  title:""				    # title (appears as link text)
  description:""		  # description (appears on hover)
  template:template		# Bounding box for widget
  className:"set"
  open:false

  events: () =>
    'click .shortcut':'toggleWidget'
  
  initialize:(options) =>
    super options
    @libs = []			# libraries this menuItem belongs to.  View context is based on this.
    if true
      lib = require "views/"+options.lib
      _ops = {params:@options.params}
      if options.contextName
        _ops.collection = application.context[@options.contextName].filtercollection
        #@filtercollection = application.context[options.contextName].filtercollection
      @widget = @addSubview @options.id, lib, '#'+options.id+"_widget", _ops
    return @

  getRenderData: =>
    id: @options.id

  toggleWidget: =>
    if @open
      @_hide()
    else
      @_show()

  _show:=>
    @options.parent.hideAll()
    @open = true
    @$el.find('.controlPane').show()
    
  _hide:=>
    @open = false
    @$el.find('.controlPane').hide()
