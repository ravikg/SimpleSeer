Model = require "models/model"
application = require 'application'
menuItem = require "views/core/menuitem"
Filters = require "collections/core/filtercollection"
Frame = require "models/frame"

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
    @attributes.menuItems = []
    if !@model?
      @model = Frame
    @filtercollection = new Filters([],{model:@model,view:@,mute:true})

  
  parse: (response) =>
    if response.menuItems? and response.menuItems.length > 0
      for o in response.menuItems
        if !application.menuItems[o.id]? and application.menuBars[o.menubar]?
          application.menuBars[o.menubar].addMenuItem o, @get('name')
          application.menuBars[o.menubar].render()
    super response
    return response
    
  save: =>
    sd = _.clone @attributes
    for o in sd.menuItems
      o.append = @_getId(o)
      delete o.parent
    super(sd)
    
  _getId: (o)=>
    # TODO: o.unique isnt unique enough
    md5( JSON.stringify(
      o.lib
      o.menubar
      o.unique
      o.params
    ) )
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