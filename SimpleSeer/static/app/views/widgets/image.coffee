[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/image")
]

module.exports = class Image extends SubView
	template: Template