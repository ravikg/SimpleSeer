[View, Template] = [
  require("views/view"),
  require("./templates/modal")
]

module.exports = class Modal extends View
  template: Template

  initialize: =>
    super()
    Application.subscribe("modal/", @receive)

  receive:(data) =>
    type = data.data.severity
    message = data.data.message

  clear: =>
    @$el.hide()

  show: =>
    @render()
    @$el.show()

  getRenderData: =>
    return {opt: JSON.stringify({form: [
      {field: "metadata.vin", type: "select", values: ["Nasty", "Awesome"], label: "Part Type"},
      {field: "metadata.tpm", type: "text", value: "", label: "Part #"},
      {field: "metadata.tpm", type: "text", value: "", label: "Lot #"},
      {field: "metadata.tpm", type: "text", value: "", label: "Machine #"},
    ]})}