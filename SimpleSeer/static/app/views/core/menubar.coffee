View = require '../view'
application = require '../../application'
template = require './templates/menubar'
menuItem = require "views/core/menuitem"


module.exports = class menuBar extends View
  template:template
  navigation:true

  initialize: =>
    @collectionGroup = {}
    super()
    if @navigation
      nmi = @addMenuItem {append:"navigation",id:"navigation",lib:"core/navmenuitem",menubar:@id}
      @navigation = nmi.widget
    return @

  events: =>
    "click #toolbar-toggle": "toggleToolbar"

  render: =>
    super()
    return @

  addMenuItem: (obj,contextName) =>
    obj.append = obj.id
    obj.contextName = contextName
    @addSubview obj.id, menuItem, '#toolset', obj
    
  hideAll: =>
    for i,o of @subviews
      o._hide?()

  toggleToolbar: =>
    toolbar = @$el.parents("#toolbar")
    toolbar.toggleClass("expanded")
    if( toolbar.hasClass("expanded") )
      @$el.find(".controlPane").removeClass("showing")

  addNavigation: (href,obj) =>
    if @navigation
      @navigation.addNavigation(href, obj)
    else
      console.error "no navigation for menuBar"

  clearNavigation: =>
    if @navigation
      @navigation.navLinks = {}
      @navigation.render()
    else
      console.error "no navigation for menuBar"
