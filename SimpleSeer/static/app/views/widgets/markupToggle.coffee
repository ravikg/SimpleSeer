[Template, SubView, application] = [
  require("views/widgets/templates/markupToggle"),
  require("views/core/subview"),
  require("application")
]

module.exports = class MarkupToggle extends SubView
  template: Template

  initialize: =>

  events: =>
  	"change #toggle-box": "updateMarkup"

  updateMarkup: =>
  	$('#part-markup').trigger("marktoggle")
