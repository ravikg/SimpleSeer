View = require './view'
template = require './templates/tabcontainer'
application = require '../application'
Filters = require "../../collections/filtercollection"
Frame = require "../models/frame"

module.exports = class TabContainer extends View  
  template: template
  sideBarOpen: application.settings.showMenu
  _tabs:{}
  #lastModel: ""
  
  initialize: (options)=>
    super()
    if !@model?
      @model = Frame
    @filtercollection = new Filters({model:@model,view:@})
    
    if options.tabs
      @tabLib = require './'+options.tabs+'/init'
        
    @filtercollection.on 'add', @setCounts
    @filtercollection.on 'reset', @setCounts

  events:
    'click #minimize-control-panel' : 'toggleMenu'
    'click #second-tier-menu .title' : 'toggleMenu'
    'click .icon-item' : 'toggleMenu'
  
  setCounts: =>
    @$el.find('#count_viewing').html @filtercollection.length
    @$el.find('#count_total').html @filtercollection.totalavail
  
  tabClick: (e,ui) =>
    console.log e,ui
    return false
  
  preFetch:()=>
    application.throbber.load()
  
  postFetch:()=>
    application.throbber.clear()
    #url = @filtercollection.getUrl(true)
    #$('#csvlink').attr('href','/downloadFrames/csv'+url)
    #$('#excellink').attr('href','/downloadFrames/excel'+url)  
  
  showMenu: (callback) =>
    @sideBarOpen = false if @sideBarOpen is undefined
    if !callback then callback = =>
      
    if @sideBarOpen is false
      @sideBarOpen = true
      $('#second-tier-menu').show("slide", { direction: "left" }, 100)
      $("#stage").animate({'margin-left':'343px'}, 100, 'linear', callback)
    else
      callback()
  
  hideMenu: (callback) =>
    @sideBarOpen = true if @sideBarOpen is undefined
    if !callback then callback = =>
      
    if @sideBarOpen is true
      @sideBarOpen = false
      $('#second-tier-menu').hide("slide", { direction: "left" }, 100)
      $("#stage").animate({'margin-left':'90px'}, 100, 'linear', callback)
    else
      callback()
  
  toggleMenu: (callback) =>
    @sideBarOpen = true if @sideBarOpen is undefined
    if !callback then callback = =>
    
    if @sideBarOpen
      for i,o of @_tabs
        if o.hideMenuCallback
          o.hideMenuCallback()
      @hideMenu(callback)
    else
      for i,o of @_tabs
        if o.showMenuCallback
          o.showMenuCallback()
      @showMenu(callback)
      
  getRenderData: =>
    count_viewing: @filtercollection.length
    count_total: @filtercollection.totalavail
    #count_new: @newFrames.length
    #sortComboVals: @updateFilterCombo(false)
    #metakeys: application.settings.ui_metadata_keys
    #featurekeys: application.settings.ui_feature_keys
    filter_url:@filtercollection.getUrl()

  render: =>
    @sideBarOpen = true
    #@filtercollection.limit = @filtercollection._defaults.limit
    #@filtercollection.skip = @filtercollection._defaults.skip
    if @rendered
      @.delegateEvents(@.events)
    @rendered = true
    super()
    for i,o of @tabLib
      _id = i+'_tab'
      @_tabs[_id] = @addSubview _id, o, '#tabs', {append:_id}
    #if @empty==true and @filtercollection.at(0)
    #  @newest = @filtercollection.at(0).get('capturetime_epoch')
    #_(@_frameViews).each (fv) =>
    #  @$el.find('#frame_holder').append(fv.render().el)
    #@$el.find('#loading_message').hide()
    #@empty=false
    #@lastLoadTime = new Date()
    $('#tabs',@$el).tabs select: (event, ui) =>
      sid = $('#tabs',@$el).tabs('option', 'selected')
      tabs = $('.ui-tabs-panel',@$el)
      @_tabs[tabs[sid].id].unselect()
      @_tabs[ui.panel.id].select()
    for i,o of @_tabs
      if o.selected
        o.select()
        $('#tabs',@$el).tabs("select", o.options.append)

    return this
