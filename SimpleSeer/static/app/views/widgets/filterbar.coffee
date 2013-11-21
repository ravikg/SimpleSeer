[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/filterbar")
]

module.exports = class FilterBar extends SubView
  template: Template

  form: [
    {id: "vin", type: "text", value: "", label: "VIN #"},
    {id: "tpm", type: "text", value: "", label: "TPM #"},
    #{id: "Machine Number", type: "text", value: "", label: "MACHINE #"},
    #{id: "tolstate", type: "select", values: ["PASS", "FAIL"], default: "-", label: "PASS / FAIL"},
  ]

  initialize:(options) =>
    super(options)
    @filters = []

  events: =>
    "click .filter": "openMenu"
    "click [data-action=apply]": "closeMenuAndApply"
    "click [data-action=cancel]": "closeMenuAndReset"
    "keypress input[type=text]": "enterToClose"

  keyEvents: =>
    {"esc": "escToClose"}

  enterToClose:(e) =>
    if e.which is 13 and @$(".filter.active").length
      e.preventDefault()
      @closeMenuAndApply()

  escToClose:(e) =>
    if @$(".filter.active").length
      e.preventDefault()
      @closeMenu()

  setMenu: =>

  openMenu:(e) =>
    @$(".filter.active").removeClass("active")
    filter = $(e.currentTarget)
    filter.addClass("active")
    offset = filter.offset().left
    @$(".menu").css("left", offset).show()

  closeMenu: =>
    @$(".filter").removeClass("active")
    @$(".menu").hide()

  closeMenuAndApply: =>
    @closeMenu()
    data = @subviews["template-form"].submit()
    @applyFitlers(data[0], data[1])

  closeMenuAndReset: =>
    @closeMenu()
    @subviews["template-form"].reset()

  applyFitlers:(results, errors) =>
    @subviews["template-form"].reset()
    for key, value of results
      if value?
        @addFilter(key, value)
    @render()

  addFilter:(key, value) =>
    @filters.push({title: "#{key}: #{value}", value: value})

  getRenderData: =>
    return {
      formoptions: JSON.stringify({"form": @form})
      filters: @filters
    }