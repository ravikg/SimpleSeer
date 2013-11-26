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
  increment: 0.5
  reflowed: false
  rendered: false
  selected: null
  frames: []
  frame: null
  ui: null

  key: "tpm"

  initialize:(options) =>
    super(options)
    $(document).on 'mouseup', (e) =>

      # Squash event memory leak for main image
      if $._data(@img[0], "events").mouseup? and $._data(@img[0], "events").mouseup.length > 0
        @img.off 'mouseup'
      if $._data(@img[0], "events").mousemove? and $._data(@img[0], "events").mousemove.length > 0
        @img.off 'mousemove'

      # Squash event memory leak for thumbnail image
      if $._data(@region[0], "events").mouseup? and $._data(@region[0], "events").mouseup.length > 0
        @region.off 'mouseup'
      if $._data(@region[0], "events").mousemove? and $._data(@region[0], "events").mousemove.length > 0
        @region.off 'mousemove'
      

  getRenderData: =>
    if @frame and @frame.get?
      id = @frame.get('id')
      imgfile = "/grid/imgfile/" + id
      thumbnail_file = "/grid/thumbnail_file/" + id
    else
      imgfile = ''
      thumbnail_file = ''

    imgfile: imgfile
    thumbnail_file: thumbnail_file

  afterRender: =>
    @_set()
    @img.drags()
    @region.drags()

    @img.load =>
      @_stats()
      @_fill()
      @_center()
      @_updateZoomer()
      @thumbnail_image.load =>
        @_updateZoomer()
      @rendered = true
      @img.css('opacity', 1.0)

      if @ui
        if @ui.image
          scale = if @ui.image.scale then @ui.image.scale else null
          e = {}
          if @ui.image.x?
            e.x = @ui.image.x
          if @ui.image.y?
            e.y = @ui.image.y
          @_zoom(e, 0, parseFloat(@ui.image.scale))

  _getFrame: (frames) =>
    frame = null
    if @selected
      for o,i in frames
        md = o.get('metadata')
        if String(md[@key]) is String(@selected)
          frame = o
          break
    else
      frame = frames[0]
    return frame

  receive: (data) =>
    @frames = data
    @frame = @_getFrame(@frames)
    @render()

  select: (params) =>
    if params
      if params[@key]?
        @selected = params[@key]
        @frame = @_getFrame(@frames)
        @render()

      if params['ui']?
        @ui = params['ui']
      else
        @ui = null

    if @reflowed and @rendered
      @reflowed = false
      @reflow()


  events: =>
    'dblclick .image': '_zoom'
    'mousewheel .image': '_mouseWheel'
    'change input[type=range]': '_range'
    'change input[type=text]': '_text'
    'updateZoomer .image img': '_updateZoomer'
    'updateZoomer .overlay .region': '_updateImage'
    'click .toggle[data-value=markup]': '_markUp'
    'click .toggle[data-value=fullscreen]': '_fullScreen'

  keyEvents: =>
    {"esc": "_exitFullScreen"}

  reflow: =>
    if @visible()
      if !@zoomed
        @_fill()
        @_center()
        @_updateZoomer()
    else
      @reflowed = true

  _stats: =>
    @width = @img.width()
    @height = @img.height()

  _set: =>
    @frame = $(@$el.get(0))
    @image = @$el.find('.image')
    @img = @$el.find('.image img')
    @zoomer = @$el.find('.zoom')
    @region = @$el.find('.region')
    @thumbnail = @$el.find('.thumbnail')
    @thumbnail_image = @$el.find('.thumbnail img')

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

  _updateZoomer: =>
    img = @$el.find('.thumbnail img')
    @thumbnail.css('height', img.height())
    scale = @img.outerWidth() / img.outerWidth()
    frame_width_scale = @frame.outerWidth() / @img.outerWidth()
    frame_height_scale = @frame.outerHeight() / @img.outerHeight()
    frame_to_thumb_width_scale = @frame.outerWidth() / img.outerWidth()
    frame_to_thumb_height_scale = @frame.outerHeight() / img.outerHeight()

    if @frame.outerWidth() >= @img.outerWidth()
      w = @img.outerWidth() / scale
      l = 0
    else 
      w = img.outerWidth() / (@img.outerWidth() / frame_to_thumb_width_scale / img.outerWidth())
      l = Math.abs(parseInt(@img.css('left'), 10)) * frame_width_scale / frame_to_thumb_width_scale

    if @frame.outerHeight() >= @img.outerHeight()
      h = @img.outerHeight() / scale
      t = 0
    else
      h = img.outerHeight() / (@img.outerHeight() / frame_to_thumb_height_scale / img.outerHeight())
      t = Math.abs(parseInt(@img.css('top'), 10)) * frame_height_scale / frame_to_thumb_height_scale

    @region.css('top', t).css('left', l).css('width', w).css('height', h)
    @$el.find('.controls input[type="text"]').val(parseInt(@scale * 100, 10) + "%")
    @$el.find('.controls input[type="range"]').attr('min', parseInt(@fillScale * 100, 10)).attr('max', parseInt(@maxScale * 100, 10)).val(parseInt(@scale * 100, 10))

  _updateImage: (e) =>
    img = @$el.find('.thumbnail img')
    scale = @img.outerWidth() / img.outerWidth()
    frame_width_scale = @frame.outerWidth() / @img.outerWidth()
    frame_height_scale = @frame.outerHeight() / @img.outerHeight()
    frame_to_thumb_width_scale = @frame.outerWidth() / img.outerWidth()
    frame_to_thumb_height_scale = @frame.outerHeight() / img.outerHeight()

    rl = parseInt(@region.css('left'), 10) 
    rt = parseInt(@region.css('top'), 10)
    il = (Math.abs(parseInt(rl)) / frame_width_scale * frame_to_thumb_width_scale) * -1
    it = (Math.abs(parseInt(rt)) / frame_height_scale * frame_to_thumb_height_scale) * -1

    @img.css('top', it).css('left', il)

  _zoom: (e, delta=0, scale=0) =>
    @zoomed = true
    if e? and e.offsetX? and e.offsetY?
      x1 = e.offsetX
      y1 = e.offsetY
      @img.css('left', (@frame.width()/2) - (x1))
      @img.css('top', (@frame.height()/2) - (y1))
    else
      @img.css('left', (@frame.width()/2))
      @img.css('top', (@frame.height()/2))

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

    if e? and e.x?
      @img.css('left', (e.x) * -1)
    if e? and e.y?
      @img.css('top', (e.y) * -1)

    @_checkBounds()
    @_updateZoomer()

  _checkBounds: =>
    if @img.outerWidth() <= @frame.outerWidth()
      if @img.offset().left < @frame.offset().left
        @img.css('left', 0)
      if @img.offset().left + @img.outerWidth() > @frame.offset().left + @frame.outerWidth()
        @img.css('left', @frame.outerWidth() - @img.outerWidth())
    else
      if @img.offset().left > @frame.offset().left
        @img.css('left', 0)
      if @img.offset().left + @img.outerWidth() < @frame.offset().left + @frame.outerWidth()
        @img.css('left', @frame.outerWidth() - @img.outerWidth())

    if @img.outerHeight() <= @frame.outerHeight()
      if @img.offset().top < @frame.offset().top
        @img.css('top', 0)
      if @img.offset().top + @img.outerHeight() > @frame.offset().top + @frame.outerHeight()
        @img.css('top', @frame.outerHeight() - @img.outerHeight())
    else
      if @img.offset().top > @frame.offset().top
        @img.css('top', 0)
      if @img.offset().top + @img.outerHeight() < @frame.offset().top + @frame.outerHeight()
        @img.css('top', @frame.outerHeight() - @img.outerHeight())

  _mouseWheel: (e) =>
    @_zoom(e, e.deltaY)

  _range: (e) =>
    @_zoom(e, 0, $(e.target).val() / 100)

  _text: (e) =>
    @_zoom(e, 0, parseInt($(e.target).val(),10) / 100)

  _markUp: (e) =>
    state = $(e.target).attr('data-state')
    if !state or state == "off"
      $(e.target).attr('title', 'Turn Markup Off')
      $(e.target).attr('data-state', 'on')
    else
      $(e.target).attr('title', 'Turn Markup On')
      $(e.target).attr('data-state', 'off')

  _fullScreen: (e) =>
    # TODO: Can we generalize this?
    # Custom title tags
    if @frame.hasClass("fullscreen")
      @frame.find(".toggles .toggle[data-value=fullscreen]").attr('title', 'Enter Fullscreen')
    else
      @frame.find(".toggles .toggle[data-value=fullscreen]").attr('title', 'Exit Fullscreen')

    @frame.toggleClass("fullscreen")
    @frame.find('div.exit').toggle()
    @_fill()
    @_center()

  _exitFullScreen: (e) =>
    @frame.removeClass("fullscreen")
    @frame.find('div.exit').css('display', 'none')
    @_fill()
    @_center()