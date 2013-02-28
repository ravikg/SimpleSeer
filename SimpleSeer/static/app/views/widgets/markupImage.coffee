SubView = require 'views/core/subview'
application = require 'application'
template = require './templates/markupImage'

# MarkupImage is a subview / widget used for
# displaying an image with a canvas overlay
# that uses Processing.js for markup to the
# image.

module.exports = class markupImage extends SubView
  # Applied to the container that this
  # widget is initialized on.
  className:"widget-markupImage"
  
  # Define some working variables.
  pjs: ''
  template: template
  img: ''
  size: [0,0]

  initialize:(options) =>
    super()
    if options.img
      @img = options.img
    return @

  getRenderData: =>
    url: @img

  afterRender: =>
    @renderProcessing()

  renderProcessing: =>
    canvas = @$el.find("canvas")
    image = @$el.find("img")
    $(canvas).width(@size[0]).height(@size[1])
    $(image).css("min-width", @size[0]).css("min-height", @size[1])
    @pjs = new Processing(canvas.get(0))
    @pjs.background(0,0)
    @pjs.size @size[0], @size[1]

  setImage: (image, size) =>
    @img = image
    @size = size
    @render()