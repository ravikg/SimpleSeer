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
    

  events: =>
    "keypress input[type=text]": "enterToApply"    

  enterToApply:(e) =>
    if e.which is 13
      e.preventDefault()
      console.log("Unimplemented")

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
    @$el.data("type", @type)