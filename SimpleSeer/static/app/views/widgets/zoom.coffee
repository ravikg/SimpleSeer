[Template, SubView, application] = [
  require("views/widgets/templates/zoom"),
  require("views/core/subview"),
  require("application")
]

module.exports = class ZoomFinder extends SubView
  template: Template

  initialize: =>
    $(document).on "click", "#menuItemZoomer .item", =>
      @$("#zoomify-box").zoomify('repaint')

  setModel:(model) =>
    @model = model
    @render()

  afterRender: =>
    @zoomEl = false
    return unless @model
    if @options.parent.active
      $(window).resize @reflow
      scale = @calculateScale()
      scaleFixed = Math.floor(scale * 100) / 100
      displayHeight = $("#part-markup").height()
      passedHeight = (displayHeight / @model.get("height")) / scale
      @$("#zoomify-box")
        .on('model', @setModel)
        .zoomify({
          y: 25
          max: 400
          min: Math.floor(scaleFixed * 100)
          zoom: scaleFixed
          realWidth: @model.get("width")
          realHeight: @model.get("height")
          image: "/grid/imgfile/#{@model?.id}"
          height: Math.min(1, passedHeight)
          onZoom: @setZoom
          onPan: @setPan
        })
      $("#part-markup").draggable
        drag: (e, ui) ->
          $(window).scrollTop(0)
          w0 = $("#content").width()
          h0 = $("#content").height()
          w = $("#part-markup").width()
          h = $("#part-markup").height()
          if ui.position.left > 0 then ui.position.left = 0
          if ui.position.top > 0 then ui.position.top = 0
          if ~ui.position.left + w0 > w
            ui.position.left = w0 - w
            #ui.position.left = 0
          if ~ui.position.top + h0 > h
            ui.position.top = h0 - h
            #ui.position.top = 0
          $("#zoomify-box").zoomify("option", {"x": ~ui.position.left / w, "y": ~ui.position.top / h})
      $("#part-markup").dblclick(@clickZoom)

  # Repeated function to calculate the
  # scale based off of the model's real
  # width and the display's width.
  calculateScale: =>
    framewidth = @model.get("width")
    realwidth = $("#part").width()
    scale = realwidth / framewidth
    return scale

  reflow: =>
    @$("#zoomify-box").zoomify("repaint")
    @zoomEl.width?($("#part")?.width())
    @zoomEl.height?($("#part")?.height())
    @zoomEl.trigger?("clickzoom")
    scale = @calculateScale()
    scaleFixed = scale.toFixed(2)
    displayHeight = $("#part-markup").height()
    passedHeight = (displayHeight / @model.get("height")) / scale
    @$("#zoomify-box").zoomify("option", "zoom", scaleFixed)
    @$("#zoomify-box").zoomify("option", "min", Math.floor(scaleFixed * 100))
    @$("#zoomify-box").zoomify("option", "height", Math.min(1, passedHeight))

  clickZoom: (e) =>
    viewPort = $("#part-markup")
    scale = $("#zoomify-box").data("orig-scale")
    fakeZoom = Number($("#zoomify-box").data("last-zoom"))
    fakeZoom *= 1.6
    clickX = e.clientX - 300
    clickY = e.clientY - 48
    oldLeft = clickX - Number($("#part-markup").css("left").replace("px", ""))
    oldTop = clickY - Number($("#part-markup").css("top").replace("px", ""))
    oldWidth = viewPort.width()
    oldHeight = viewPort.height()
    newWidth = (@model.attributes.width * fakeZoom)
    newHeight = (@model.attributes.height * fakeZoom)
    newLeft = oldLeft / oldWidth * newWidth
    newTop = oldTop / oldHeight * newHeight
    x = Number($("#part-markup").css("left").replace("px", "")) - (newLeft - oldLeft)
    y = Number($("#part-markup").css("top").replace("px", "")) - (newTop - oldTop)
    $("#zoomify-box").zoomify("option", {zoom: Math.floor((fakeZoom*100))/100, x: (-x) / newWidth, y: (-y)/ newHeight})
    return

  setZoom:(params, e) =>
    if !@zoomEl
      @zoomEl = $("#part-markup")
      @zoomEl.css({position: "relative"})
    @zoomEl.height(@model.get("height")*e.zoom)
    @zoomEl.width(@model.get("width")*e.zoom)
    $("#zoomify-box").data("last-zoom", e.zoom)
    @zoomEl.trigger("clickzoom")

  setPan:(params, e) =>
    if !@zoomEl
      @zoomEl = $("#part-markup")
      @zoomEl.css({position: "relative"})

    @zoomEl.css({'top':~((@model.get("height")*e.y)*e.zoom)})
    @zoomEl.css({'left':~((@model.get("width")*e.x)*e.zoom)})



