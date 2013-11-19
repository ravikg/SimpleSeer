[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/metadata")
  require("models/frame")
]

module.exports = class MetaData extends SubView
	template: Template