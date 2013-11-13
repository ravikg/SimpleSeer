[View, Template] = [
	require("views/view"),
	require("./templates/toolbar")
]

module.exports = class Toolbar extends View
	template: Template

	getRenderData: =>
		client: Application.settings.ui_pagename

	addWidget:(name, widget) =>
		#@addSubview(name, widget, @$(".right"))