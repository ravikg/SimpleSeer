[View, Template] = [
	require("views/view"),
	require("./templates/toolbar")
]

module.exports = class Toolbar extends View
	template: Template

	initialize: =>
		super()
		@items = 0

	getRenderData: =>
		client: Application.settings.ui_pagename

	addItem:(view) =>
		name = "menuitem-#{@items++}"
		options = { append: @$(".right") }
		sv = @addSubview(name, require(view), null, options)
		sv.render()

	afterRender: =>
		@addItem("views/menuitem")
		@addItem("views/menuitem")