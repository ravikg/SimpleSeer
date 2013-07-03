[Application, TabContainer, Dashboard] = [
  require("application"),
  require("models/core/tab_container"),
  require("views/core/dashboard")
]

module.exports = class SeerRouter extends Backbone.Router
  routes =
    "admin": "admin"

  initialize: =>
    #panel = new TabContainer()
    #Application.tabs.add(panel)
    for route, handler of routes
      @route(route, handler)

  admin: ->
    Application.modal.clear()
    #yaml = new Dashboard()
    #yaml.select()
