Model = require "../model"
MenuItem = require "/models/core/menuitem"

module.exports = class Context extends Model
  url: "/api/context"
  #model: MenuItem
  
  initialize: =>
    @menuItems =[]
  
  parse: (response) =>
    console.log response.menuItems
    for o in response.menuItems
      @menuItems.push new MenuItem(o)
    super response

