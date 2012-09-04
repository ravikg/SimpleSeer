View = require "./view"
template = require "./templates/framedetail"
application = require "application"
markupImage = require "./widgets/markupImage"

# FrameDetailView contains a full-screen annotated
# view of a frame record, and provides manipulation
# controls for the view as well as a table of
# properties on that frame model.

module.exports = class FrameDetailView extends View
  # Localize the view template.
  template: template

  # Inject blank values for undefined keys
  # in the metadata. Add event handler for
  # the window resize.
  initialize: (frame)=>
    super()
    for k in application.settings.ui_metadata_keys
      if !frame.model.attributes.metadata[k]?
        frame.model.attributes.metadata[k] = ""
    @frame = frame.model
    $(window).resize => @updateScale()
    return
  
  # Event handlers.
  events:
    "click .clickEdit": "setDirty"
    "click .notes-field": "setDirty"
    "change .clickEdit": "updateMetaData"
    "click #toggleProcessing" : "togglePro"
    "change .notes-field" : "updateMetaData"
    "dblclick #display-zoom": "clickZoom"
    "click .savebtn": "setSaved"
    "focus .clickEdit": "showSaved"
    "blur .clickEdit": "hideSaved"
    "focus .notes-field": "showSaved"
    "blur .notes-field": "hideSaved"

  # Handles the display of the save button in the
  # metadata box.
  showSaved: => @$el.find(".savebtn").show()
  hideSaved: => @$el.find(".savebtn").hide()

  # Show / hide the canvas markup layer
  # for the view.
  togglePro: => $("#display canvas").toggle()

  # Returns the annotated frame properties
  # to the template.
  getRenderData: =>
    data = {}
   
    if @model.get("features").length
      data.featuretypes = _.values(@model.get("features").groupBy (f) -> f.get("featuretype"))
    
    for k of @model.attributes
      data[k] = @model.attributes[k]
    data.disabled = application.settings.mongo.is_slave || false

    md = @frame.get("metadata")
    metadata = []
    for i in application.settings.ui_metadata_keys
      metadata.push {key:i,val:md[i]}
      
    data.metadata = metadata
    data.capturetime_epoch = new moment(parseInt(@frame.get("capturetime_epoch"))).format("M/D/YYYY h:mm a")
    return data

  setSaved: =>
    @$el.find(".savebtn").button("option", "label", "Saved")
    @$el.find(".savebtn").button("disable")
    return

  setDirty: =>
    @$el.find('.savebtn').button("enable")
    @$el.find('.savebtn').button("option", "label", "Save")
    @$el.find('.savebtn').show()
    return

  # Loops through table keys and values
  # and updates the database with the
  # inputs.
  updateMetaData: =>
    rows = @$el.find(".editableMeta tr")
    rows.each (id, obj) =>
      tds = $(obj).find("td")
      input = $(tds[0]).find("input")
      span = $(tds[0]).find("span")[0]
      @model.attributes.metadata[$(span).html()] = input.attr("value")
    @model.attributes.notes = $(".notes-field").attr("value")
    @model.save()
    @setSaved()
    return
    
  # Called when the user double-clicks on
  # the view. Will zoom in by a set percent.
  clickZoom: (e) ->
    viewPort = $("#display-zoom")
    scale = $("#zoomer").data("orig-scale")
    
    # Get the current zoom level and add 20%.
    fakeZoom = Number($("#zoomer").data("last-zoom"))
    fakeZoom += .2
    
    # Find the position of the click relative
    # to the view.
    clickX = e.clientX - 300
    clickY = e.clientY - 48
    oldLeft = clickX - Number($("#display-zoom").css("left").replace("px", ""))
    oldTop = clickY - Number($("#display-zoom").css("top").replace("px", ""))
    oldWidth = viewPort.width()
    oldHeight = viewPort.height()
    
    # Calculate the new position and size for
    # the image relative to the center of the
    # click.
    newWidth = (@.model.attributes.width * fakeZoom)
    newHeight = (@.model.attributes.height * fakeZoom)
    newLeft = oldLeft / oldWidth * newWidth  
    newTop = oldTop / oldHeight * newHeight
    x = Number($("#display-zoom").css("left").replace("px", "")) - (newLeft - oldLeft)
    y = Number($("#display-zoom").css("top").replace("px", "")) - (newTop - oldTop)
    
    # Update the view's frame with the new
    # size calculations.
    $("#zoomer").zoomify("option", {zoom: Math.floor((fakeZoom*100))/100, x: (-x) / newWidth, y: (-y)/ newHeight})
    $('#display').css("height", (@.model.attributes.height * scale))
    return
  
  # Called when the user activates the
  # slider on the zoomify widget.
  zoom: (e, ui) ->
    scale = $("#zoomer").data("orig-scale")
    $("#display").css "height", @.model.attributes.height * scale
    $("#display-zoom").css
      "position": "relative",
      "top": "-" + (@.model.attributes.height * ui.zoom * ui.y) + "px",
      "left": "-" + (@.model.attributes.width * ui.zoom * ui.x) + "px",
      "width": (@.model.attributes.width * ui.zoom) + "px",
      "height": (@.model.attributes.height * ui.zoom) + "px",
    
    # Update the markup canvas only if the
    # zoom level changed since last time.
    if ui.zoom != Number($("#zoomer").data("last-zoom")) then @imagePreview.renderProcessing()
    $("#zoomer").data("last-zoom", ui.zoom)
    return

  # Repeated function to calculate the
  # scale based off of the model's real
  # width and the display's width.
  calculateScale: =>
    framewidth = @model.get("width")
    realwidth = $("#display").width()
    scale = realwidth / framewidth
    return scale

  # Called when the window is resized, so
  # that we can re-render the markupImage
  # with the new scale.
  updateScale: =>
    scale = @calculateScale()
    
    # Save energy and only update the display
    # if the scale actually changed.
    unless scale is $("#zoomer").data("orig-scale")
      fullHeight = $(window).height() - 48
      ui = {zoom: $("#zoomer").data("last-zoom")}
      
      $("#display-zoom").css
        "position": "relative",
        "width": (@.model.attributes.width * ui.zoom) + "px",
        "height": (@.model.attributes.height * ui.zoom) + "px",
      
      $("#display").css("height", @.model.attributes.height * scale)
      $("#zoomer").data("orig-scale", scale)
      $("#zoomer").zoomify "option",
        min: (scale.toFixed(2)) * 100,
        max: 400,
        height: (fullHeight / @model.get("height")) / scale,
        zoom: scale.toFixed(2)
        
    return
  
  # Initialize all of the widgets and
  # ui elements in the view.
  postRender: =>
    @$el.find(".savebtn").button()
    @$el.find(".savebtn").hide()
    @setSaved()

    application.throbber.clear()
    scale = @calculateScale()
    scaleFixed = scale.toFixed(2)
    displayHeight = $(window).height() - 48;

    # Create new markupImage in the view.
    @imagePreview =  @addSubview("display-zoom", markupImage, "#display-zoom")
    @imagePreview.setModel(@model)
    
    # Zoomify widget for image navigation.
    $("#zoomer")
      .data("orig-scale", scale)
      .zoomify
        y: 25
        max: 400
        min: scaleFixed * 100
        zoom: scaleFixed
        realWidth: @model.get("width")
        realHeight: @model.get("height")
        image: @model.get('imgfile')
        height: (displayHeight / @model.get("height")) / scale
        update: (e, ui) =>
          @zoom(e, ui)
      
    # Allows the notes field to expand
    # and shrink to fit the value of the
    # field.
    @$el.find(".notes-field").autogrow()
    
    # Adds pan-by-drag functionality to the
    # display.
    $("#display-zoom").draggable
      drag: (e, ui) ->
        w0 = $("#frameHolder").width()
        h0 = $("#frameHolder").height()
        w = $("#display-zoom").width()
        h = $("#display-zoom").height()
        if ui.position.left > 0 then ui.position.left = 0
        if ui.position.top > 0 then ui.position.top = 0
        if -1*ui.position.left + w0 > w then ui.position.left = w0 - w
        if -1*ui.position.top + h0 > h then ui.position.top = h0 - h
        $("#zoomer").zoomify("option", {"x": -1*ui.position.left / w, "y": -1*ui.position.top / h})
    
    return
    
