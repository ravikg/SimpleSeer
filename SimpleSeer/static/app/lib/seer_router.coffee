[Application, TabContainer, Dashboard] = [
  require("application"),
  require("models/core/tab_container"),
  require("views/core/dashboard")
]

module.exports = class SeerRouter extends Backbone.Router

  initialize: =>
    super()

  admin: ->
    Application.modal.clear()

