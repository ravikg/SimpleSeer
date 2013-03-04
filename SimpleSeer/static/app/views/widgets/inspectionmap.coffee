SubView = require 'views/core/subview'
template = require './templates/inspectionmap'
application = require 'application'
markupImage = require 'views/widgets/markupImage'

module.exports = class inspectionMap extends SubView
  template: template
  expanded: false
  lastMap: ""
  mapThumbnails:
    driver:
      pass: "/img/map/driver_pass.png"
      fail: "/img/map/driver_fail.png"
      full: "/img/map/driver_full.png"
      size: [276, 92]
    passenger:
      pass: "/img/map/passenger_pass.png"
      fail: "/img/map/passenger_fail.png"
      full: "/img/map/passenger_full.png"
      size: [276, 92]
    back:
      pass: "/img/map/back_pass.png"
      fail: "/img/map/back_fail.png"
      full: "/img/map/back_full.png"
      size: [116, 92]
  mapOrder: [
    {
      name: "driver"
      pass: ""
      thumbnail: "/img/map/driver_blank.png"
    },
    {
      name: "back"
      pass: ""
      thumbnail: "/img/map/back_blank.png"      
    },
    {
      name: "passenger"
      pass: ""
      thumbnail: "/img/map/passenger_blank.png"     
    }
  ]
  
  events: =>
    "click .map-figure": "expandFigure"
    "click .canvas-map": "closeFigure"
    "mousemove canvas": "mouseCheck"

  initialize: =>
    @markup = @addSubview "markup", markupImage, ".canvas-map .graphic"
    @maths = {'driver':[],'back':[],'passenger':[]}
    for camera in application.settings.cameras
      @maths[camera.map].push @stringToList(camera.location,@mapThumbnails[camera.map].size)

  mouseCheck: (event) =>
    os = $(event.target).offset()
    _x = Math.round(event.pageX-os.left)
    _y = Math.round(event.pageY-os.top)
    for coords in @maths[@lastMap]
      if _x > coords[0] and _x < (coords[0]+coords[2]) and _y > coords[2] and _y < (coords[1]+coords[3])
        console.log 'in'
        
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
    pjs.fill(if result.string is "0" then 0x8800aa00 else 0x88aa0000)
    pjs.stroke(if result.string is "0" then 0x8800ff00 else 0x88ff0000)
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
      @$el.find(".canvas-map").show("slide", {direction: "up", duration: 200})
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
    @$el.find(".canvas-map").hide("slide", {direction: "up", duration: speed})
    @hideTriangle()
    @expanded = false
    parent.removeClass("expanded")

  closeAllFigures: =>
    _.each @options.parent.subviews, (view) =>
      unless view is @
        if view instanceof inspectionMap and view.expanded is true
          view.closeFigure(0)

  mergeCamera: =>   
    _.each @model.attributes.results, (result, id) =>
      cam = _.findWhere(SimpleSeer.settings.cameras, {name: result.inspection_name})
      @model.attributes.results[id].map = cam.map
      @model.attributes.results[id].camera = cam

  getRenderData: => 
    @mergeCamera()
    final = []; maps = []; fails = {}
    _.each @model.attributes.results, (result) =>
      maps.push result.camera.map
      if result.string is "1"
        fails[result.camera.map] = 1
    _.each _.uniq(maps), (map) =>
      pf = (if fails[map] == 1 then "fail" else "pass")
      parent = _.findWhere @mapOrder, {name: map}
      _.extend parent, {pass: pf, thumbnail: @mapThumbnails[map][pf]}
    return {model: @model, maps: @mapOrder}
