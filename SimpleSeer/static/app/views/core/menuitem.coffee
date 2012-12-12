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
    @filtercollection = application.context[options.contextName].filtercollection
    @libs = []			# libraries this menuItem belongs to.  View context is based on this.
    return @

  getRenderData: =>
    id: @options.id

  render: =>
    if !@rendered
      super()
      lib = require "views/"+@options.lib
      @widget = @addSubview @options.id, lib, '#'+@options.id+"_widget", {params:@options.params,collection:application.context[@options.contextName].filtercollection}
      @widget.render()
      @rendered = true
    return @

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
