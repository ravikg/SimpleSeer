[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/filter")
]

module.exports = class Filter extends SubView
  template: Template

  initialize:(options) =>
    super(options)

    @title = options.title || ""
    @value = options.value || ""

    # Can be one of:
    # - select
    # - multiselect
    # - field
    # - date
    # - time
    @type  = options.type || "field"

    # Need something for the old autofill 
    # filters.
    

  events: =>
    "keypress input[type=text]": "enterToApply"
    "keyup input[type=text]": "updateClearButtons"
    "click [data-action=clear]": "clearData"

  clearData: =>
    @$("input[type=text]").val("")
    @$("[data-action=clear]").hide()
    # trigger param removal

  updateClearButtons:(e) =>
    if !$(e.currentTarget).val().length
      @$("[data-action=clear]").hide()
    else if $(e.currentTarget).val().length
      @$("[data-action=clear]").show()
  
  enterToApply:(e) =>
    if e.which is 13
      e.preventDefault()
      console.log("Unimplemented")
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
    #@$el.attr("data-key", @type)
    @$el.attr("data-label", @title)

  toJSON: =>
    return {title: @title, value: @value, type: @type}