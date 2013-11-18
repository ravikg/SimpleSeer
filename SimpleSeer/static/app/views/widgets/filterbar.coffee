[ SubView, Template ] = [
	require("views/subview"),
	require("./templates/filterbar")
]

module.exports = class FilterBar extends SubView
	template: Template