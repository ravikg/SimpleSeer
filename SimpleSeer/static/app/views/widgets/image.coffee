[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/image")
]

module.exports = class Image extends SubView
  template: Template
  scale: 1
  fillScale: 1
  width: 0
  height: 0
  zoomed: false
  maxScale: 5
  increment: .5

  events: =>
    'dblclick .image': '_zoom'
    'mousewheel .image': '_mouseWheel'
    'change input[type=range]': '_range'
    'change input[type=text]': '_text'

  reflow: =>
    if !@zoomed
      @_fill()
      @_center()
      @_updateZoomer()

  getRenderData: =>
    thumbnail_path: "http://image.europeancarweb.com/f/tires/products/epcp_1103_bridgestone_america_new_ultra_high_performance_tires/32457691/epcp-1103-05-o%2Bbridgestone-america-new-ultra-high-performance-tires%2BRE960AS.jpg"
    image_path: "http://image.europeancarweb.com/f/tires/products/epcp_1103_bridgestone_america_new_ultra_high_performance_tires/32457691/epcp-1103-05-o%2Bbridgestone-america-new-ultra-high-performance-tires%2BRE960AS.jpg"

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
      @_updateZoomer()


  _stats: =>
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
    @fillScale = @scale

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

  _updateZoomer: =>
    @$el.find('.controls input[type="text"]').val(parseInt(@scale * 100, 10) + "%")
    @$el.find('.controls input[type="range"]').attr('min', parseInt(@fillScale * 100, 10)).attr('max', parseInt(@maxScale * 100, 10)).val(parseInt(@scale * 100, 10))

  _zoom: (e, delta=0, scale=0) =>
    @zoomed = true
    
    if e.offsetX? and e.offsetY?
      x1 = e.offsetX
      y1 = e.offsetY
      @img.css('left', (@frame.width()/2) - (x1))
      @img.css('top', (@frame.height()/2) - (y1))
    
    w1 = @img.width()
    h1 = @img.height()

    if delta
      if delta > 0
        @scale += @increment
      if delta < 0
        @scale -= @increment
      if @scale > @maxScale
        @scale = @maxScale
    else
      if @scale * 1.5 > @maxScale
        @scale = @maxScale
      else 
        @scale *= 1.5

    if scale
      if scale > @maxScale
        @scale = @maxScale
      else
        @scale = scale

    if @scale < @fillScale
      @_fill()
      @_center()
    else
      @img.width(@width * @scale)
      @img.height(@height * @scale)
      w2 = @img.width()
      h2 = @img.height()

      @img.css('left', parseInt(@img.css('left'), 10) - ((w2 - w1) / 2))
      @img.css('top', parseInt(@img.css('top'), 10) - ((h2 - h1) / 2))

    @_updateZoomer()

  _mouseWheel: (e) =>
    @_zoom(e, e.deltaY)

  _range: (e) =>
    @_zoom(e, 0, $(e.target).val() / 100)

  _text: (e) =>
    @_zoom(e, 0, parseInt($(e.target).val(),10) / 100)