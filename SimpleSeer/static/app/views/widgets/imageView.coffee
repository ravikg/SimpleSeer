SubView = require 'views/core/subview'
template = require './templates/imageView'
application = require 'application'
Frame = require "models/frame"

module.exports = class imageView extends SubView
  className:"imageView"
  tagName:"div"
  template: template  

  initialize: =>
    super()
    
  events:
    'change input':'updateMetaData'
  
  getRenderData: =>
    md = @model.get('metadata')
    metadata = []
    if application.settings.ui_metadata_keys?
      for i in application.settings.ui_metadata_keys
        metadata.push {key:i,val:md[i]}
    retVal =
      capturetime_epoch: new moment(parseInt @model.get('capturetime_epoch')).format("M/D/YYYY h:mm a")
      camera: @model.get('camera')
      imgfile: @model.get('imgfile')
      thumbnail_file: @model.get('thumbnail_file')
      id: @model.get('id')
      features: @model.get('features')
      metadata: metadata
      width: @model.get('width')
      height: @model.get('height')
      notes: @model.get('notes')
      url:'/grid/imgfile/'+@model.id
    retVal

  updateMetaData: =>
    metadata = {}
    
    rows = @$el.find("tr")
    rows.each (id, obj) ->
      tds = $(obj).find('td')
      input = $(tds[1]).find('input')
      span = $(tds[0]).find('span')
      metadata[$(span).html()] = input.attr('value')
    @model.save {metadata: metadata}


  renderTableRow: (table) =>
    awesomeRow = []
    rd = @getRenderData()
    awesomeRow['Capture Time'] = rd.capturetime_epoch
    for i in rd.metadata
      awesomeRow[i.key] = i.val
    #if rd.features.models
    #  console.log rd.features.models[0].tableData()
    #  f = rd.features.models[0].getPluginMethod(rd.features.models[0].get("featuretype"), 'metadata')()
    #else
    #  f = {}
    #pairs = {}
    #for i,o of f
    #  awesomeRow[o.title + o.units] = o.value
    table.addRow(awesomeRow)
