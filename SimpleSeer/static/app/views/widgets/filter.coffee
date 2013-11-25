[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/filter")
]

module.exports = class Filter extends SubView
  template: Template

  initialize:(options) =>
    super(options)

    @field = options.field || ""
    @title = options.title || ""
    @value = options.value || ""

    # Can be one of:
    # - select
    # - multiselect
    # - field
    # - date
    # - time
    @type  = options.type || "field"
    
  events: =>
    "keypress input[type=text]": "enterToApply"
    "keyup input[type=text]": "onInputKeyUp"
    "click [data-action=clear]": "clearData"

  clearData: =>
    @$("input[type=text]").val("")
    @$("[data-action=clear]").hide()
    @value = null
    @signalFilterRefresh()

  onInputKeyUp:(e) =>
    if !@value
      @$("input[type=text]").addClass("unsaved")
      @$("[data-action=clear]").hide()
    else
      @$("input[type=text]").removeClass("unsaved")
      @$("[data-action=clear]").show()
  
  enterToApply:(e) =>
    if e.which is 13
      e.preventDefault()
      @value = $(e.currentTarget).val()
      @signalFilterRefresh()
    else 

  getPlural: =>
    if @value instanceof Array && @value.length > 1
      return "s"
    else
      return ""

  getValue: =>
    if @value instanceof Array && @value.length > 1
      return @value.join(", ")
    else
      return @value

  setValue:(value) =>
    @value = value
    @render()
    @onInputKeyUp()

  getFriendlyLabel: =>
    switch @type
      when "field"
        return "#{@title}:"
      else
        return "#{@title}#{@getPlural()} #{@getValue()}"

  getRenderData: =>
    return {
      friendly: @getFriendlyLabel(),
      value: @value,
      type: @type
    }

  afterRender: =>
    @$el.attr("data-type", @type)
    @$el.attr("data-value", JSON.stringify(@value))
    @$el.attr("data-key", @field)
    @$el.attr("data-label", @title) 

  toJSON: =>
    if !@value
      return null
    return {field: @field, value: @value}

  signalFilterRefresh: =>
    @options.parent.filtersToURL()