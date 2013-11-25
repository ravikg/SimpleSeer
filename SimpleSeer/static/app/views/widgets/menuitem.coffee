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
    if options.onClick?
      @onClick = options.onClick

  getRenderData: =>
    return {
      title: @title
      icon: @icon
    }
