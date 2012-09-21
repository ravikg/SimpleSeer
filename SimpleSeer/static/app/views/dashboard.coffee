template = require './templates/dashboard'
application = require '../application'
Tab = require './tab_view'
model = require '../models/dashboard'
Chart = require '../models/chart'

module.exports = class Dashboard extends Tab
  building:false
  template: template
  chartTypes: {"area":"Area","bar":"Bar","line":"Line","spline":"Spline","column":"Column","scatter":"Scatter"}
  
  initialize: =>
    @model = new model {id:"5047bc49fb920a538c000000",view:@}
    #load or create collection from server
    #cycle through, and @addGraph(new graph)
    @colors = ['red', 'green', 'blue']
    @chart = new Chart()
    super()
  
  render: =>
    @model.fetch()
    super()
  
  afterRender: =>
    wg = @$el.find("#widget_grid")
    wg.disableSelection() 
    wg.sortable
      handle: ".header"
      start: @preDragDrop
      stop: @afterDragDrop
      cancel: ".button"
    @$el.find('select.chartinput').combobox {selected: @changeDrop}
    #@$el.find('select.chartinput').each (i,item) =>
    #  @changeDrop i,{item:$(item).children()[0]}
    @$el.find('#chartbuilder :selected').each (i,item) =>
      @changeDrop i,{item:item}
    @$el.find('.chartStyleType').each (i,item) =>
      $(item).on "click", (event) =>
        @chart.set "style", event.target.value
    super()

  changeDrop: (event, ui) =>
    if ui.item
      ele = $(ui.item)
      parent = ele.parent()
      names = []
      for obj in parent.children()
        names.push $(obj).text()
      name = parent.attr('name')
      if name == "olap_xaxis"
        target = 'input[name="xTitle"]'
      else if name == "olap_yaxis"
        target = 'input[name="yTitle"]'
      tarEl = @$el.find(target)
      if tarEl.attr("value") == "" || tarEl.attr("value") in names
        tarEl.attr("value",ele.text())
      #console.log ele.val()
      #console.log ele.text()
    return

  preDragDrop: (a,b) =>
    # clear floats
      
  afterDragDrop: (a,b) =>
    if a
      # recalculate floats
      @cleanList()
      @saveWidgets()
    #always return true.  Returning false cancels the move
    return true

  saveWidgets: =>
    children = @$el.find("#widget_grid").children()
    widgets = []
    for current in children
      widgets.push @subviews[$(current).attr('id')].toJson()
    @model.attributes.widgets = widgets
    @model.save({success:=>})
  
  
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
    styles: @chartTypes
    
  getVariables: =>
    vars = []
    dataFields = @chart.get "dataMap"
    if not dataFields
      dataFields = [{}]
    isset ={x:false,y:false}
    for k in application.settings.ui_filters_framemetadata
      isx = false
      if k.field_name == dataFields[0]
        isx = true
      isy = false
      for f in dataFields[1..]
        if k.field_name == f
          isy = true
      vars.push({'fieldname': k.type + '.' + k.field_name, 'varname': k.label, 'isx': isx, 'isy': isy})
    if !isset["x"]
      vars[0]["isx"] = true
    if !isset["y"]
      vars[1]["isy"] = true
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
    
