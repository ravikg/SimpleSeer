[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/sidebar")
  require("models/frame")
]

module.exports = class SideBar extends SubView
  template: Template
  frames: []
  selected: null
  full: false

  # TODO: Put in YAML
  title: "ASSEMBLIES"
  key: 'tpm'

  initialize: (options) =>
    super(options)

  receive: (data) =>
    @frames = data
    @render()
    if @scrollTop
      @$el.find("div[data-scroll=infinite]").scrollTop(@scrollTop)
      @scrollTop = 0

  update: (data) =>
    if data
      if data.channel = "frameupdate/"
        dv = if data.data.metadata?[@key]? then data.data.metadata[@key] else ''
        notes = if data.data.notes then data.data.notes else ''
        if dv
          if notes
            if @$(".item[data-value=#{dv}] .status .note-box").length is 0
              @$(".item[data-value=#{dv}] .status").append('<div class="note-box"></div>')
          else
            if @$(".item[data-value=#{dv}] .status .note-box").length is 1
              @$(".item[data-value=#{dv}] .status .note-box").remove()

  select: (params) =>
    if params and params[@key]?
      if @selected != params[@key]
        @selected = params[@key]
        @afterRender()
      
  events: =>
    'click .header': '_slide'
    'click .item': '_select'
    'mousemove .resize': 'reciprocate'

  reciprocate: =>
    @options.parent.reflow()

  _slide: (e) =>
    $(@$el.get(0)).attr 'data-state', (if $(@$el.get(0)).attr('data-state') is 'closed' then 'open' else 'closed')
    setTimeout(@reciprocate,10)

  _select: (e) =>
    @$el.find('.item.active').removeClass('active')
    item = $(e.target).closest('.item')
    item.addClass('active')
    value = item.attr('data-value')
    Application.router.setParam(@key, value)
    @options.parent.select(Application.router.query)

  _scroll: (e) =>
    if not @full
      scrollHeight = e.target.scrollHeight
      outerHeight = $(e.target).outerHeight()
      scrollTop = e.target.scrollTop

      if (scrollHeight - outerHeight) == scrollTop
        if @options.parent.load?
          @scrollTop = scrollTop
          @options.parent.load()

  getRenderData: =>
    title: @title
    frames: @frames

  afterRender: =>
    # TODO: Make this generalized
    @$el.find("div[data-scroll=infinite]").off('scroll').on('scroll', @_scroll)

    if @selected
      @$el.find(".item.active").removeClass('active')
      @$el.find(".item[data-value=#{@selected}]:first").addClass('active')
    else
      @$el.find(".item:first").addClass('active')


 