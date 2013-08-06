[Application, SubView, Template] = [
  require('application'),
  require('views/core/subview'),
  require('./templates/login')
]

module.exports = class LoginMenu extends SubView
  template: Template

  events: =>
    "click": "handleClick"

  render: =>
    @$el.off("click")
    super()
    @

  afterRender: =>
    @$el.on("click", @handleClick)

  handleClick:(e) =>
    if $(e.target).data("action") is "logout"
      window.location = "/logout"
    else
      if Application.currentUser?
        @$('#userBox').fadeIn(150)
      else
        window.location = "/login"

  getRenderData: =>
    "authed": Application.currentUser?
    "user": Application.currentUser
