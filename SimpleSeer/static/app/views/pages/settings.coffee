[Page, Template] = [
  require("views/page"),
  require("./templates/settings")
]

module.exports = class SettingsPage extends Page
  template: Template

  initialize: =>
    super()
    @title = "Settings"
