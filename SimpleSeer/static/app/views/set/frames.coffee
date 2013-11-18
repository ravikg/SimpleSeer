[ SubView, Template ] = [
	require("views/subview"),
	require("./templates/frames")
]

module.exports = class FramesView extends SubView
	template: Template

	afterRender: =>
		console.log @subviews