[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/filter")
]

module.exports = class Filter extends SubView
  template: Template

  initialize:(options) =>
    super(options)
    # Can be one of:
    # - select, multiselect, text, date, time
    @type  = options.type || "text"
    @field = options.field || ""
    @title = options.title || ""
    @value = options.value || ""
    
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
    # display bg if no value but text entered
    # display close if value
    if !@value?
      @$("[data-action=clear]").hide()
    else
      @$("[data-action=clear]").show()

    val = @$("input[type=text]").val()
    if @value != val
      if val.replace(/\s/g, "") is "" and (@value is null or @value is undefined)
        @$("input[type=text]").removeClass("unsaved")
      else
        @$("input[type=text]").addClass("unsaved")
    else
      @$("input[type=text]").removeClass("unsaved")    


  enterToApply:(e) =>
    if e.which is 13
      e.preventDefault()
      @value = $(e.currentTarget).val()
      if @value.replace(/\s/g, "") is ""
        @value = null
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
        return "#{@title}"
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