template = require './templates/dashboard'
application = require '../application'
Tab = require './tab_view'
model = require '../models/dashboard'
Chart = require '../models/OLAP'

module.exports = class Dashboard extends Tab
  building:false
  template: template
  chartTypes: {area:"Area",line:"Line",column:"Column",scatter:"Scatter"}
  
  events:
    'click .accordion .head': 'toggleAccordion'
    'click .save': 'saveChart'
    'click .cancel': 'hideBuilder'  
  
  initialize: =>
    @model = new model {id:"5047bc49fb920a538c000000",view:@}
    @colors = ['red', 'green', 'blue']
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
    @setChart new Chart()
    @$el.find('.chartColor[type="color"]').each (i,item) =>
      $(item).on "change", (event) =>
        @setChartColor event
    palette = application.palette
    @$el.find("input[type=color]").spectrum({
      showPalette: true
      showSelectionPalette: false
      palette: [palette.getPalette()]
      color: "#f00"
      change: =>
        @$el.find("#palette_select + .ui-combobox input").val("Custom")
    });
      
    #$(@el).ready @cleanList
    #$(@el).bind "focus", @cleanList

    @$el.load ->
      return
    #@buildPalettePreview()
    super()

  setChartColor: (event) =>
    #@updateChartBuild()
    @chart.setColor(event.target.name, event.target.value)
    @chart.view?.setColor(event.target.name, event.target.value)
    return true

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

  preDragDrop: (a,b) ->
    $(b.item[0]).css "z-index":1500
      
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
  
  getChartSettings: =>
    vars: @getVariables()
    styles: @chartTypes
    
  getVariables: =>
    vars = []
    #dataFields = @chart.get "dataMap"
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

  reflow: =>
    for i,o of @subviews
      o.reflowChart()
    return
  
  saveChart: =>
    $('.chartinput',@$el).each (i, o) =>
      @fieldUpdate o.name, o.value
    @saveform()

  saveform: =>
    @chart.save {},
      success: (item) =>
        widget =
          cols:1
          id:item.id
          model:"/OLAP"
          name:item.get("name")
          view:"/charts/highcharts/HCSpline"
        found = false
        for o,i in @model.attributes.widgets
          if o.id == item.id
            found = true
            widget.cols = @model.attributes.widgets[i].cols
            @model.attributes.widgets[i] = widget
        if not found
          @model.attributes.widgets.push widget
        @model.loaded = false
        @model.save()
        @hideBuilder()
        @clearSubviews()

  fieldUpdate: (name, value)=>
    newElem = {}
    newElem[name] = value
    @chart.set(newElem)

  showBuilder: =>
    grid = @$el.find("#widget_grid")
    controls = @$el.find('.graphBuilderControls')
    preview =  @$el.find('.graphBuilderPreview')
    controls.show("slide", { direction: "left" }, 300)
    preview.show("slide", { direction: "right" }, 300)
    grid.animate({opacity: 0}, 500)
    @building = true

  hideBuilder: =>
    grid = @$el.find("#widget_grid")
    controls = @$el.find('.graphBuilderControls')
    preview =  @$el.find('.graphBuilderPreview')
    controls.hide("slide", { direction: "left" }, 0)
    preview.hide("slide", { direction: "right" }, 0)
    grid.animate({opacity: 1}, 0)
    @building = false
      
  toggleBuilder: =>
    grid = @$el.find("#widget_grid")
    controls = @$el.find('.graphBuilderControls')
    preview =  @$el.find('.graphBuilderPreview')
    
    if @building
      controls.hide("slide", { direction: "left" }, 300)
      preview.hide("slide", { direction: "right" }, 300)
      grid.animate({opacity: 1}, 500)
    else
      @updateChartBuild()
      preview.width @$el.width() - controls.width() - 42 + "px"
      grid.animate({opacity: 0}, 300)
      controls.show("slide", { direction: "left" }, 500)
      preview.show("slide", { direction: "right" }, 500)
      
    @building = !@building 
    return false
    
  toggleAccordion:(e) =>
    if $(e.currentTarget).parents(".group").hasClass("expanded")
      @$el.find(".expanded").removeClass("expanded").find(".content").slideUp()
    else 
      @$el.find(".expanded").removeClass("expanded").find(".content").slideUp()
      current = $(e.currentTarget).parents(".group")
      current.addClass("expanded").find(".content").slideDown()
        
  select: =>
    super()
    @draw()
    return true
  
  draw: =>    
    $("#addGraph").die("click").live("click", (e, ui)=>
      @setChart new Chart()
      e.preventDefault()
      @showBuilder()
      return false
    )
    @$el.find("#colSpin").attr("max", @cols)
    #@$el.find(".graphBuilderPreview").css("width", 0)
    @$el.find(".accordion .group.expanded .content").slideDown()
    @$el.find("select").combobox()
    @$el.find("#palette_select").combobox
      selected: => @buildPalettePreview()
    
    #controls = @$el.find('.graphBuilderControls')
    #preview =  @$el.find('.graphBuilderPreview')
    #controls.hide("slide", { direction: "left" }, 0)
    #preview.hide("slide", { direction: "right" }, 0)
    @hideBuilder()
    @building = false
    return true

  setChart: (model) =>
    @chart = model
    @updateChartBuild()
        
  updateChartBuild: =>
    style = @chart.get("style") || "line"
    @$el.find('input[value="'+style+'"]')[0].checked = true
    @$el.find("input[name=chartColor]").spectrum("set", @chart.get("color") || "#0074b5");
    #@$el.find("input[name=chartTitleColor]").spectrum("set", @chart.get("titleColor") || "#555");
    #@$el.find("input[name=chartLabelColor]").spectrum("set", @chart.get("labelColor") || "#555");
    @$el.find('input[name="name"]').attr "value", @chart.get("name") || ""
    @$el.find('input[name="xTitle"]').attr "value", @chart.get("xTitle") || @$el.find('[name="olap_xaxis"] option:selected').text()
    @$el.find('input[name="yTitle"]').attr "value", @chart.get("yTitle") || @$el.find('[name="olap_yaxis"] option:selected').text()

  buildPalettePreview: =>
    # Get the palette
    palette = application.palette
    palette.setScheme @$el.find("#palette_select").val()
    scheme = palette.getPalette()
    
    # Update spectrum
    @$el.find("input[type=color]").spectrum("destroy").spectrum({
      showPalette: true
      showSelectionPalette: false
      palette: [palette.getPalette()]
      color: "#f00"
      change: =>
        @$el.find("#palette_select + .ui-combobox input").val("Custom")
    });

    # Update the property colors
    @$el.find("input[name=chartColor]").spectrum("set", scheme[1]);
    #@$el.find("input[name=chartTitleColor], input[name=chartLabelColor]").spectrum("set", scheme[0]);
    @setCPalette()

  cleanList: =>
    #console.log @$el.is ":visible"
    #reset the margin-top of all grid items
    children = @$el.find("#widget_grid").children()
    children.css('margin-top',0)
    i=0
    totalCols=0
    tops = []
    for current in children
      current = $(current)
      x = (totalCols%@cols)+1
      y = (totalCols%@cols)+parseInt current.attr('cols')
      #if tops[x]
      #if tops[y]
      #console.log current.offset().top
      before = current.prev("li")
      #console.log [x,y]
      totalCols += parseInt current.attr('cols')
      if before.length > 0 && before.height() < current.height() && !(i%@cols)
        diff = before.height() - current.height()
        current.next("li").css('margin-top',diff)
      i++
 
  getRenderData: =>
    palettes = application.palette.getSchemes()
    for i of palettes
      if palettes[i].id is application.palette.getScheme() then palettes[i].default = true
    widgets = []
    cw = 100/@cols
    for i,o of @testData
      _w = {}
      _w["cols"] = o.cols
      _w["title"] = i
      _w["width"] = cw*o.cols
      if o.height
        _w["boxHeight"] = o.height + 10
        _w["height"] = o.height
      widgets.push _w
    return {palettes: palettes, widgets:widgets, chartSettings:@getChartSettings()}


