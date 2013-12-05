[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/markup"),
  require("models/frame")
]

module.exports = class Markup extends SubView
  template: Template

  getRenderData: =>
    message: "Hello"