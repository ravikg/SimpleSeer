[MenuItem] = [ require("views/widgets/menuitem") ]

module.exports = class UserMenuItem extends MenuItem

  initialize:(options) =>
  	super(options)
  	@title = "Login"
  	@icon  = "/img/seer/Header_Image_User.svg"

  getRenderData: =>
  	return {
  		title: @title
  		icon: @icon
  	}

  onClick: =>
    Application.pages.loadPageByName("settings")
