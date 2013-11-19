[SubView, Template] = [
  require("views/subview"),
  require("./templates/menuitem")
]

module.exports = class MenuItem extends SubView
  template: Template

  initialize:(options) =>
  	super(options)
  	@title = options.title || ""
  	@icon  = options.icon  || "/img/seer/Header_Image_Settings.svg"

  getRenderData: =>
  	return {
  		title: @title
  		icon: @icon
  	}

  onClick: =>
    Application.pages.loadPageByName("settings")
