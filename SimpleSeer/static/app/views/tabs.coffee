[View, Template] = [
	require("views/view"),
	require("./templates/tabs")
]

module.exports = class Tabs extends View
	template: Template

	getRenderData: =>
		client: Application.settings.ui_pagename