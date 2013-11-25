module.exports = class Modal

  initialize: =>
    Application.subscribe("modal/", @receive)

  receive:(data) =>
    type = data.data.severity
    message = data.data.message

  clear: =>

  show: =>

