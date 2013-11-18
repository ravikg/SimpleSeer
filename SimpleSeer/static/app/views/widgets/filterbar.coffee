[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/filterbar")
]

module.exports = class FilterBar extends SubView
  template: Template
  form: [
    {id: "email", type: "text", value: "", label: "E-Mail:", required: true},
    {id: "name", type: "text", value: "", label: "Name:"},
    {id: "pw", type: "password", value: "", label: "Password:"},
    {id: "sex", type: "radio", values: ["Male", "Female"], label: "Sex:"},
    {id: "color", type: "checkbox", values: ["Green", "Red", "Blue"], label: "Color:"}
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

  getRenderData: =>
    return {formoptions: JSON.stringify({"form": @form})}
