[View, Template, Collection] = [
	require("views/view"),
	require("./templates/tabs"),
	require("collections/tabs")
]

module.exports = class Tabs extends View
	template: Template

	initialize: =>
		super()
		@collection = new Collection()
		@collection.fetch({success: @lol})

	lol: =>
		console.log arguments

	getRenderData: =>
		tabs: [
			{title: "Dashboard", active: false},
			{title: "Data", active: true},
			{title: "Charts", active: false},
			{title: "Reports", active: false},
		]