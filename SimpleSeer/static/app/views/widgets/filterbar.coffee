[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/filterbar")
]

module.exports = class FilterBar extends SubView
  template: Template

  form: [
    {id: "vin", type: "text", value: "", label: "VIN #"},
    {id: "tpm", type: "text", value: "", label: "TPM #"},
  ]

  initialize:(options) =>
    super(options)
    @filters = []

  events: =>
    "click .filter": "openMenu"
    "click [data-widget=Filter][data-type*=select]": "openMenu"
    "click [data-action=apply]": "closeMenuAndApply"
    "click [data-action=cancel]": "closeMenuAndReset"

  keyEvents: =>
    {"esc": "escToClose"}

  escToClose:(e) =>
    if @$(".filter.active").length
      e.preventDefault()
      @closeMenu()

  setMenu: =>

  openFilterEdit:(e) =>
    @openMenu(e)

  openMenu:(e) =>
    filter = $(e.currentTarget)
    offset = filter.offset().left
    if !filter.hasClass("add")
      @form = [{id: filter.data("key"), type: "checkbox", values: filter.data("value"), label: filter.data("label")}]
      @subviews["template-form"].options.form = @form
      @subviews["template-form"].render()
    @$(".filter.active").removeClass("active")
    filter.addClass("active")      
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
    @filters.push({label: "#{key}: #{value}", value: value, key: key})

  getRenderData: =>
    return {
      formoptions: JSON.stringify({"form": @form})
      filters: @filters,
      locked: true
    }