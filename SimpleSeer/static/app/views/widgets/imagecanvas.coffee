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

	getRenderData: =>
		image: @options.image

	afterLoad: =>
		if @loaded
			@_scale()
			@_align()
			@_markup(@options.engine)

	afterRender: =>
		@canvas = @$("canvas")
		@image = @$("img")
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
		[w, h] = [@image.attr("data-w"), @image.attr("data-h")]
		box =
			width: @options.width - @options.padding * 2,
			height: @options.height - @options.padding * 2

		# Check if we need to scale down the image itself.
		wider = (w > box.width)
		taller = (h > box.height)
		if(wider or taller)
			scaleW = box.width / w
			scaleH = box.height / h
			@_scaleFactor = Math.min(scaleH, scaleW)
			@image.width(w * @_scaleFactor)
			@image.height(h * @_scaleFactor)	

		@canvas.width @image.width() + @options.padding * 2
		@canvas.height @image.height() + @options.padding * 2		

	# The markup method is called each
	# time the view is rendered. It draws
	# on the canvas. No drawing is done by
	# default.
	_markup:(engine = =>) =>
		[w, h] = [@canvas.width(), @canvas.height()]
		[w1, h1] = [@image.width(), @image.height()]
		@_process()
		@processing.size w, h
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