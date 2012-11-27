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
  urlRoot: "/api/context"
  _defaultMenuItem:
    lib:false
    params:{}
    unique:0
    menubar:"main"
  
  parse: (response) =>
    if response.menuItems.length > 0
      for o in response.menuItems
        if !application.menuItems[o.id]? and application.menuBars[o.menubar]?
          application.menuItems[o.id] = application.menuBar[o.menubar].addSubview o.id, o.lib, '#'+o.id, {params:o.params,collection:@,append:"filter_" + o.id}
    super response
    
  fetch:(options=[]) =>
    if @attributes.name? and !@attributes.id?
      @url = "/context/"+@attributes.name
      options = success: =>
        delete @url
    super options
  
  addMenuItem:(obj) =>
    if obj.lib?
      @attributes.menuItems.push obj
    else
      console.error "lib required"

  _syncMenuItems: =>
    mi = @menuItems
    @attributes.menuItems = []
    for o in mi
      @attributes.menuItems.push o.attributes