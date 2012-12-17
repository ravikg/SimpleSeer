SubView = require '../subview'
application = require '../../application'
template = require './templates/menuitem'

module.exports = class menuItem extends SubView
  icon:""			        # filename of icon
  title:""				    # title (appears as link text)
  color: ""           # color of tabs
  description:""		  # description (appears on hover)
  template:template		# Bounding box for widget
  className:"set"
  open:false

  events: () =>
    'click .shortcut':'toggleWidget'
    'dblclick .title': 'toggleLevel'
  
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
      @title = @widget.options.params?.label
    return @

  render: =>
    super()
    @$el.removeClass("red yellow blue").addClass(@color)
    return @

  getRenderData: =>
    id: @options.id
    title: @title
    color: @color
    icon: @icon

  setColor:(color) =>
    @color = color
    @render()

  toggleWidget: =>
    if @open
      @_hide()
    else
      @_show(true)

  toggleLevel: =>
    if @$el.parents("#toolbar").hasClass("expanded")
      @$el.find(".content").toggle()

  _show:(closeAll=false) =>
    if closeAll then @options.parent.hideAll()
    @open = true
    @$el.find('.controlPane').css('display', 'block').find(".content").show()
    
  _hide:=>
    @open = false
    @$el.find('.controlPane').css('display', 'none')
