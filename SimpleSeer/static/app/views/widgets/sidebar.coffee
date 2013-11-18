[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/sidebar")
]

module.exports = class SideBar extends SubView
  template: Template

  getRenderData: =>
  	title: "ASSEMBLIES"