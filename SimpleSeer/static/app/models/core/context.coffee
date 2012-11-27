Model = require "../model"
application = require '../../application'

###
menuItem:
  params
  lib
  unique
  menubar
###

module.exports = class Context extends Model
  url: "/api/context"
  #model: MenuItem
  
  initialize: =>
    @menuItems =[]
    super
  
  parse: (response) =>
    obj = response[0]
    if obj.menuItems.length > 0
      for o in obj.menuItems
        @menuItems.push application.loadMenuItem o
        #@menuItems.push new MenuItem(o)
    super obj
    
    
  _syncMenuItems: =>
    mi = @menuItems
    @attributes.menuItems = []
    for o in mi
      @attributes.menuItems.push o.attributes

  save: =>
    @_syncMenuItems()
    super