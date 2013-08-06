[Application, SubView, Template] = [
  require('application'),
  require('views/core/subview'),
  require('./templates/login')
]

module.exports = class LoginMenu extends SubView
  template: Template

  events: =>
    "click": "handleClick"

  handleClick: =>
    if @currentUser?
      window.location = "/logout"
      @currentUser = undefined
    else
      window.location = "/login"

  getRenderData: =>
    "authed": Application.currentUser?
    "user": Application.currentUser
