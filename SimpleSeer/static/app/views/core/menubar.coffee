View = require '../view'
application = require '../../application'
template = require './templates/menubar'
menuItem = require "views/core/menuitem"


module.exports = class menuBar extends View
  template:template

  initialize: =>
    @collectionGroup = {}
    super()
    return @

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


