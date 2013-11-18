[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/filterbar")
]

module.exports = class FilterBar extends SubView
  template: Template

  form: [
    {id: "email", type: "text", value: "", label: "PART #"},
    {id: "name", type: "text", value: "", label: "LOT #"},
    {id: "pw", type: "password", value: "", label: "MACHINE #"},
    {id: "location", type: "select", values: ["PASS", "FAIL"], label: "PASS/FAIL"}
  ]

  events: =>
    "click .addFilter": "addFilter"
    "click [data-action=apply]": "closeFilter"

  addFilter: =>
    @$(".addFilter").addClass("active")
    offset = @$(".addFilter").offset().left
    @$(".menu").css("left", offset).show()

  closeFilter: =>
    @$(".addFilter").removeClass("active")
    @$(".menu").hide()
    console.log @subviews["template-form"].submit()

  getRenderData: =>
    return {formoptions: JSON.stringify({"form": @form})}