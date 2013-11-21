[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/image")
]

module.exports = class Image extends SubView
  template: Template
  scale: 1
  width: 0
  height: 0
  zoomed: false

  getRenderData: =>
    thumbnail_path: "http://thumbs3.ebaystatic.com/d/l1024/m/mFg2Eyg_HcnM0rZKWZZCjUg.jpg"
    image_path: "http://thumbs3.ebaystatic.com/d/l1024/m/mFg2Eyg_HcnM0rZKWZZCjUg.jpg"

  reflow: =>
    if !@zoomed
      @_fill()
      @_center()
      @_zoom()

  afterRender: =>
    @_set()
    @img.drags()
    $(document).on 'mouseup', =>
      @img.trigger 'imageReleased'
    @img.bind 'checkBounds', (e) =>
      @_bounds()
    @img.load =>
      @_stats()
      @_fill()
      @_center()
      @_zoom()


  _stats: =>
    console.log 'FRAME:', 'w', @frame.width(), 'h', @frame.height(), 'offset', @frame.offset()
    console.log 'IMAGE:', 'w', @image.width(), 'h', @image.height(), 'offset', @image.offset()
    console.log 'IMG:', 'w', @img.width(), 'h', @img.height(), 'offset', @img.offset()
    @width = @img.width()
    @height = @img.height()

  _set: =>
    @frame = $(@$el.get(0))
    @image = @$el.find('.image')
    @img = @$el.find('.image img')
    @zoomer = @$el.find('.zoom')

  _fill: =>

    if @frame.width() > @img.width()
      if @img.width < @width
        @img.width(@frame.width())
      else
        @img.width(@width)
        @img.height('auto')

    if @frame.height() > @img.height()
      if @img.height < @height
        @img.height(@frame.height())
      else
        @img.height(@height)
        @img.width('auto')

    if @frame.width() < @img.width()
      @img.width(@frame.width())
      @img.height('auto')

    if @frame.height() < @img.height()
      @img.height(@frame.height())
      @img.width('auto')

    @scale = @img.width() / @width
    console.log @scale

  _center: =>
    @img.css('position', 'absolute')
    @img.css('left', (@frame.width()/2) - (@img.width()/2))
    @img.css('top', (@frame.height()/2) - (@img.height()/2))

  _bounds: =>
    # Left boundary
    if (@frame.offset().left - @img.offset().left) > @img.width() - 10
      @img.css('left', -@img.width() + 10)

    # Right boundary
    if @frame.width() < @img.offset().left - @frame.offset().left
      @img.css('left', @frame.width() - 10)

    # Top boundary
    if (@frame.offset().top - @img.offset().top) > @img.height() - 10
      @img.css('top', -@img.height() + 10)

    # Bottom boundary
    if @frame.height() < @img.offset().top - @frame.offset().top
      @img.css('top', @frame.height() - 10)

  _zoom: =>
    @$el.find('.controls input[type="text"]').val(parseInt(@scale * 100, 10) + "%")