Model = require "../model"
application = require '../../application'
menuItem = require "views/core/menuitem"
Filters = require "../../collections/filtercollection"
Frame = require "../frame"

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
    menubar:"left-main"
  
  initialize: =>
    if !@model?
      @model = Frame
    @filtercollection = new Filters([],{model:@model,view:@,mute:true})

  
  parse: (response) =>
    if response.menuItems.length > 0
      for o in response.menuItems
        if !application.menuItems[o.id]? and application.menuBars[o.menubar]?
          application.menuBars[o.menubar].addMenuItem o, @get('name')
    super response
    application.menuBars[o.menubar].render()
    return response
    
  save: =>
    sd = _.clone @attributes
    for o in sd.menuItems
      delete o.parent
    super(sd)
    
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