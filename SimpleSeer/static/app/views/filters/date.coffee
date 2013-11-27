[ SubView, Template ] = [
  require("views/subview"),
  require("views/widgets/templates/filter")
]

module.exports = class Filter extends SubView
  template: Template

  initialize:(options) =>
    super(options)
    @type  = "datetime"
    @field = "capturetime_epoch"
    @title = "Date & Time"
    @value = null
    @_expanded = false
    
  events: =>
    "click": "toggleMenu"

  toggleMenu: =>
    if @_expanded
      @value = [new Date(2013, 5, 5, 5, 0, 0), new Date(2013, 8, 5, 7, 0, 0)]
      @$el.removeClass("active")
      @render()
    else
      @$el.addClass("active")
    @_expanded = !@_expanded

  clearData: =>
    @$("input[type=text]").val("")
    @$("[data-action=clear]").hide()
    @value = null
    @signalFilterRefresh()

  getValue: =>
    min = moment(@value[0]).calendar()
    max = moment(@value[1]).calendar()
    return "#{min} - #{max}"

  setValue:(value) =>
    @value = value
    @render()
    @onInputKeyUp()

  getFriendlyLabel: =>
    if @value is null
      return @title
    else
      return @getValue()

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