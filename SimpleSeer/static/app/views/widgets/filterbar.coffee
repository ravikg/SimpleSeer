[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/filterbar")
]

module.exports = class FilterBar extends SubView
  template: Template

  form: [
    {id: "vin", type: "text", value: "", label: "VIN"},
    {id: "tpm", type: "text", value: "", label: "TPM"},
    #{id: "Machine Number", type: "text", value: "", label: "MACHINE #"},
    #{id: "tolstate", type: "select", values: ["PASS", "FAIL"], default: "-", label: "PASS / FAIL"},
  ]

  initialize:(options) =>
    super(options)
    @filters = []

  events: =>
    "click .addFilter": "openMenu"
    "click [data-action=apply]": "closeMenuAndApply"
    "click [data-action=cancel]": "closeMenuAndReset"

  openMenu: =>
    @$(".addFilter").addClass("active")
    offset = @$(".addFilter").offset().left
    @$(".menu").css("left", offset).show()

  closeMenu: =>
    @$(".addFilter").removeClass("active")
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
