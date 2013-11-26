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
