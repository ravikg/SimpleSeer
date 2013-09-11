SubView = require 'views/core/subview'
template = require './templates/inspectionmap'
application = require 'application'
markupImage = require 'views/widgets/markupImage'

module.exports = class inspectionMap extends SubView
  template: template
  expanded: false
  lastMap: ""
  mapThumbnails: application.settings.mapThumbnails
  mapOrder: application.settings.mapThumbnails
  
  events: =>
    "click .map-figure": "expandFigure"
    "mousemove canvas": "mouseCheck"
    "click canvas": "clickCanvas"

  initialize: =>
    @markup = @addSubview "markup", markupImage, ".canvas-map .graphic"
    @maths = {}
    for k,v of @mapThumbnails
      @maths[k] = []
    for camera in application.settings.cameras
      if camera.location? and camera.map? and camera.name?
        @maths[camera.map].push
          name: camera.name
          coords: @stringToList(camera.location,@mapThumbnails[camera.map].size)

  clickCanvas: (event) =>
    map = $(event.target).parents(".region").attr("data-map")
    os = $(event.target).offset()
    _x = event.pageX-os.left.round()
    _y = event.pageY-os.top.round()
    for camera in @maths[@lastMap]
      coords = camera.coords
      if (_x > coords[0]) and (_x < (coords[0]+coords[2])) and (_y > coords[2]) and (_y < (coords[1]+coords[3]))
        vin = $(event.target).parents(".im-block").attr("data-vin")
        application.router.navigate encodeURI("#stats/Inspection_History/#{vin}/#{camera.name}"), true
        return

  mouseCheck: (event) =>
    os = $(event.target).offset()
    _x = Math.round(event.pageX-os.left)
    _y = Math.round(event.pageY-os.top)
    count = 0
    for camera in @maths[@lastMap]
      coords = camera.coords      
      if _x > coords[0] and _x < (coords[0]+coords[2]) and _y > coords[2] and _y < (coords[1]+coords[3])
        count++
    $(event.target).css("cursor", if count > 0 then "pointer" else "default")
        
  stringToList:(str, size) =>
    list = str.split(/\,\s*/)
    list[2] -= list[0]
    list[3] -= list[1]
    list[0] *= size[0]
    list[1] *= size[1]
    list[2] *= size[0]
    list[3] *= size[1]
    list = _.map(list, ((e) -> return Math.round(e)))
    return list

  renderResult:(pjs, result, size) =>
    box = @stringToList result.camera.location, size
    pjs.stroke(if result.string is "0" then 0xFF00AA00 else 0xFFAA0000)
    pjs.fill(if result.string is "0" then 0x8800FF00 else 0x88FF0000)
    pjs.strokeWeight 3
    pjs.rect(box[0], box[1], box[2], box[3])

  expandFigure:(e) =>
    parent = @$el.parents(".record-list-item")
    map = $(e.target).attr "data-map"
    size = @mapThumbnails[map].size

    if @expanded and @lastMap is map
      @closeFigure()
      return

    @closeAllFigures()
    @lastMap = map
    @markup.setImage @mapThumbnails[map].full, size
    @$el.find(".graphic").width(size[0]).height(size[1])

    insps = _.where(@model.attributes.results, {map: map})
    _.each insps, (result) =>
      @renderResult(@markup.pjs, result, size)

    @moveAndShowTriangle($(e.target).position().left + $(e.target).width()/2 - 5)
    if @expanded is false
      parent.addClass("expanded")
      cm = @$el.find(".canvas-map")
      cw = $(cm.prev()).width()
      cm.css("width", "#{cw}px")
        .show("slide", {direction: "up", duration: 200}, => cm.css("width", "100%"))
      @expanded = true

  moveAndShowTriangle:(left) =>
    tri = @$el.find(".arrow")
    tri.css
      "left": "#{left}px"
      "display": "block"

  hideTriangle: =>
    tri = @$el.find(".arrow")
    tri.css "display": "none"

  closeFigure:(speed=200) =>
    parent = @$el.parents(".record-list-item")
    cm = @$el.find(".canvas-map")
    cw = $(cm.prev()).width()
    cm.css("width", "#{cw}px")
      .hide("slide", {direction: "up", duration: speed}, => cm.css("width", "100%"))    
    @hideTriangle()
    @expanded = false
    parent.removeClass("expanded")

  closeAllFigures: =>
    _.each @options.parent.subviews, (view) =>
      unless view is @
        if view instanceof inspectionMap and view.expanded is true
          view.closeFigure(0)

  mergeCamera: =>   
    if @model.attributes.results
      _.each @model.attributes.results, (result, id) =>
        cam = _.findWhere(SimpleSeer.settings.cameras, {name: result.inspection_name})
        if cam
          @model.attributes.results[id].map = cam.map
          @model.attributes.results[id].camera = cam

  getRenderData: => 
    @mergeCamera()
    final = []; maps = []; fails = {}
    if @model.attributes.results?
      _.each @model.attributes.results, (result) =>
        if result.camera
          maps.push result.camera.map
          if result.string is "1"
            fails[result.camera.map] = 1
      if maps
        _.each _.uniq(maps), (map) =>
          pf = (if fails[map] == 1 then "fail" else "pass")
          parent = _.findWhere @mapOrder, {name: map}
          _.extend parent, {pass: pf, thumbnail: @mapThumbnails[map][pf]}
    return {model: @model, maps: @mapOrder}