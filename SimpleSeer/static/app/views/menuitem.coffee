[SubView, Template] = [
	require("views/subview"),
	require("./templates/menuitem")
]

module.exports = class MenuItem extends SubView
	template: Template
