[Template, SubView] = [
  require('views/widgets/templates/imagecanvas'),
  require('views/core/subview')
]

# ImageCanvas provides a image and
# a canvas bound to a Processing.js
# object. This widget handles dirty
# tasks like handling scale.

module.exports = class ImageCanvas extends SubView
  template: Template
  canvas: {}
  image: {}
  processing: undefined
  _scaleFactor: 1
  loaded: false

  showMarkup: =>
    @canvas.show?()
    return @

  hideMarkup: =>
    @canvas.hide?()
    return @

  toggleMarkup: =>
    @canvas.toggle?()

  getRenderData: =>
    image: @options.image

  afterLoad: =>
    if @loaded
      @_scale()
      @_align()
      @_markup(@options.engine)

  afterRender: =>
    #@canvas = @$("canvas")
    @canvas = @$el.find("canvas")
    if @options.stealth then @hideMarkup()
    #@image = @$("img")
    @image = @$el.find("img")
    @image.load =>
      @image.attr("data-w", @image.get(0).width)
      @image.attr("data-h", @image.get(0).height)
      @loaded = true
      @image.show()
      @afterLoad()

  _process: =>
    if !@processing?
      @processing = new Processing(@canvas.get(0))

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

    [w, h] = [@image.width(), @image.height()]
    left = Math.floor((@options.width - w) / 2)
    top = Math.floor((@options.height - h) / 2)

    @image.css
      "left": "#{left}px"
      "top": "#{top}px"

    @canvas.css
      "left": "#{left - @options.padding}px"
      "top": "#{top - @options.padding}px"

  # The scale method is called when
  # the canvas and image need to be
  # sized to the parent container.
  _scale: =>
    unless @options.scaling is false
      [w, h] = [@image.data("w"), @image.data("h")]
      box =
        width: @options.width - @options.padding * 2,
        height: @options.height - @options.padding * 2
      # Check if we need to scale down the image itself.
      wider = (w > box.width)
      taller = (h > box.height)
      scaleW = box.width / w
      scaleH = box.height / h
      @_scaleFactor = Math.min(scaleH, scaleW)
      @image.width(w * @_scaleFactor)
      @image.height(h * @_scaleFactor)
      @canvas.width @image.width() + @options.padding * 2
      @canvas.height @image.height() + @options.padding * 2
    else
      @canvas.width @options.width
      @canvas.height @options.height
      @image.width @options.width
      @image.height @options.height
      @_scaleFactor = @image.width() / @image.attr("data-w")


  # The markup method is called each
  # time the view is rendered. It draws
  # on the canvas. No drawing is done by
  # default.
  _markup:(engine = =>) =>
    [w, h] = [@canvas.width(), @canvas.height()]
    [w1, h1] = [@image.width(), @image.height()]
    @_process()
    @processing.size w, h
    if @model
      @processing.scale w1 / @model.get("width")
    else
      @processing.scale w1 / @image.attr "data-w"
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

