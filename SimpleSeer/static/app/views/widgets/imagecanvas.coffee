[Template, SubView] = [
  require('views/widgets/templates/imagecanvas'),
  require('views/core/subview'),
]

# ImageCanvas provides a image and
# a canvas bound to a Processing.js
# object. This widget handles dirty
# tasks like handling scale.

module.exports = class ImageCanvas extends SubView
  initialize: =>
    @template = Template
    @processing = undefined
    @_scaleFactor = 1
    @loaded = false
    super()

  showMarkup: =>
    @$("canvas").show?()
    return @

  hideMarkup: =>
    @$("canvas").hide?()
    return @

  toggleMarkup: =>
    @$("canvas").toggle?()

  getRenderData: =>
    image: @options.image

  afterLoad: =>
    if @loaded
      @_scale()
      @_align()
      @_markup(@options.engine)

  afterRender: =>
    if @options.stealth then @hideMarkup()
    @$("img").load =>
      if @$("img").get(0)?
        @$("img").attr("data-w", @$("img").get(0).width)
        @$("img").attr("data-h", @$("img").get(0).height)
        @loaded = true
        @$("img").show()
        @afterLoad()

  _process: =>
    if !@processing?
      @processing = new Processing(@$("canvas").get(0))

  # The align method is called when
  # the widget is given a padding option.
  # Padding is used to push the image
  # away from the edges of the canvas to
  # prevent any clipping of the markup.
  _align: =>
    if @options.layout is "centered"
      # If the user wants to center the images
      # themselves, provide an option.
      return

    [w, h] = [@$("img").width(), @$("img").height()]
    left = Math.floor((@options.width - w) / 2)
    top = Math.floor((@options.height - h) / 2)

    @$("img").css
      "left": "#{left}px"
      "top": "#{top}px"

    @$("canvas").css
      "left": "#{left - @options.padding}px"
      "top": "#{top - @options.padding}px"

  # The scale method is called when
  # the canvas and image need to be
  # sized to the parent container.
  _scale: =>
    unless @options.scaling is false
      [w, h] = [@$("img").data("w"), @$("img").data("h")]
      box =
        width: @options.width - @options.padding * 2,
        height: @options.height - @options.padding * 2
      # Check if we need to scale down the image itself.
      wider = (w > box.width)
      taller = (h > box.height)
      scaleW = box.width / w
      scaleH = box.height / h
      @_scaleFactor = Math.min(scaleH, scaleW)
      iw = w * @_scaleFactor; @$("img").width iw
      ih = h * @_scaleFactor; @$("img").height ih
      @$("canvas").width iw + @options.padding * 2
      @$("canvas").height ih + @options.padding * 2
    else
      @$("canvas").width @options.width
      @$("canvas").height @options.height
      @$("img").width @options.width
      @$("img").height @options.height
      @_scaleFactor = @$("img").width() / @$("img").attr("data-w")


  # The markup method is called each
  # time the view is rendered. It draws
  # on the canvas. No drawing is done by
  # default.
  _markup:(engine = =>) =>
    [w, h] = [@$("canvas").width(), @$("canvas").height()]
    [w1, h1] = [@$("img").width(), @$("img").height()]
    @_process()
    @processing.size w, h
    if @model
      @processing.scale w1 / @model.get("width")
    else
      @processing.scale w1 / @$("img").attr "data-w"
    @processing.background 0, 0
    engine(@processing, @options, [w1, h1])

  width:(value) =>
    if value? then @options.width = value
    @afterLoad()
    return @options.width

  height:(value) =>
    if value? then @options.height = value
    @afterLoad()
    return @options.height

  repaint: =>
    @_markup(@options.engine)

  setFeature:(feature) =>
    @options.feature = feature
    @afterLoad()

  setImage:(image) =>
    @loaded = false
    @processing = undefined
    @options.image = image
    @render()

  remove: =>
    @$("img").off().unbind()
    for trash in @el.children
      if trash?
        @el.removeChild(trash)
    delete @processing
