SubView = require './subview'
application = require '../application'
template = require './templates/menuItem'

module.exports = class menuItem extends SubView
  icon:""				# filename of icon
  title:""				# title (appears as link text)
  description:""		# description (appears on hover)
  template:template		# Bounding box for widget

  events: =>
    "click":"toggleWidget"
    "click .title": "switchPaneEvent"
    "click .context": "showContextEvent"
    
  toggleWidget: =>
    console.log 'toggle'
    
  # -== OLD WINDOW.COFFEE CODE ==-
  panes: []

  initialize:(content) =>
    @libs = []			# libraries this menuItem belongs to.  View context is based on this.
    super()
    @panes = content
    return

  render: =>
    super()
    return

  afterRender: =>
    for i in @panes
      @$el.find(".content div[data-tab=#{i.id}]").append(i.content)
    @selectPane(@panes[0].id)
    return
    
  getRenderData: =>
    return {pane:@panes}

  deselectPanes: =>
    @$el.find(".title.active").removeClass("active")
    @$el.find(".content div").hide()
    return

  selectPane:(pane) =>
    @deselectPanes()
    @$el.find(".title[data-tab=#{pane}]").addClass("active")
    @$el.find(".content div[data-tab=#{pane}]").show()
    return
    
  switchPaneEvent:(e, ui) =>
    target = $(e.currentTarget)
    id = target.data("tab")
    @selectPane(id)
    return

  showContextEvent: =>
    # Loop through panes context and
    # generate menu.
    console.log "Worked."
    