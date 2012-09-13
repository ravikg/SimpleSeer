template = require './templates/dashboard'
application = require '../application'
Tab = require './tab_view'
model = require '../models/dashboard'
Chart = require '../models/chart'

module.exports = class Dashboard extends Tab
  building:false
  template: template
  
  initialize: =>
    @model = new model {id:"5047bc49fb920a538c000000",view:@}
    @model.fetch()
    #load or create collection from server
    #cycle through, and @addGraph(new graph)
    @colors = ['red', 'green', 'blue']
    @styles = ['bar', 'line', 'spline', 'pie', 'scatter']
    @chart = new Chart()
    super()
  
  createGraph: =>
    #create graph from settings
    #graph = new GraphView
    #graph.save()
    @addGraph(graph)
        
  addGraph: (graph) =>
    #add div to grid
    #draw graph to div
    #if graph.id not in collection, collection.add and save

        
  getRenderData: =>
    vars: @getVariables()
    attrib: @chart.attributes
    colors: @getColors()
    styles: @getStyles()
    
  getVariables: =>
    vars = []
    dataFields = @chart.get "dataMap"
    if not dataFields
      dataFields = [{}]
    
    for k in application.settings.ui_filters_framemetadata
      isx = false
      if k.field_name ==  dataFields[0]
        isx = true
      
      isy = false
      for f in dataFields[1..]
        if k.field_name == f
          isy = true
        
      vars.push({'fieldname': k.type + '.' + k.field_name, 'varname': k.label, 'isx': isx, 'isy': isy})
    vars
    
  getColors: =>
    cols = []
    modelcolor = @chart.get "color"
        
    for c in @colors
      isycolor = false
      if  modelcolor == c
        isycolor = true
    
      cols.push({'colorname': c, 'isycolor': isycolor})
    cols

  getStyles: =>
    sty = []
    modelstyle = @chart.get "style"
    
    for s in @styles
      isstyle = false
      if  modelstyle == s
        isstyle = true
    
      sty.push({'stylename': s, 'isstyle': isstyle})
    sty
    
