SubView = require '../subview'
application = require '../../application'
template = require './templates/menuitem'

module.exports = class menuItem extends SubView
  icon:""			        # filename of icon
  title:""				# title (appears as link text)
  color:""        # color of tab
  description:""		  # description (appears on hover)
  template:template		# Bounding box for widget
  className:"set"
  open:false

  events: () =>
    'click .shortcut':'toggleWidget'
  
  initialize:(options) =>
    @className += " " + @color
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

  setMeta:(options) =>
    console.log options
    if options.title
      @title = options.title
    if options.color
      @color = options.color
    if options.icon
      @icon = options.icon
      console.log @$el.find(".shortcut")
      @$el.find(".shortcut").html("background-image") #, "url(\"" + @icon + "\")");

  getRenderData: =>
    id: @options.id
    title: @title
    color: @color
    icon: @icon

  toggleWidget: =>
    if @open
      @_hide()
    else
      @_show(true)

  _show:(closeAll=false) =>
    if closeAll then @options.parent.hideAll()
    @open = true
    @$el.find('.controlPane').css('display', 'block')
    
  _hide:=>
    @open = false
    @$el.find('.controlPane').css('display', 'none')
