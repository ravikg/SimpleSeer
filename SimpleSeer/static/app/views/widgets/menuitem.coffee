[SubView, Template] = [
  require("views/subview"),
  require("./templates/menuitem")
]

module.exports = class MenuItem extends SubView
  template: Template

  initialize:(options) =>
    super(options)
    @title = options.title
    @icon  = options.icon
    @onClick = options.onClick || =>

  getRenderData: =>
    return {
      title: @title
      icon: @icon
    }
