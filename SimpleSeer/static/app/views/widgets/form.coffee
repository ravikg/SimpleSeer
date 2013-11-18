[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/form")
]

module.exports = class Form extends SubView
  template: Template

  getRenderData: =>
  	items = []
  	for item in @options.form
  		items.push(item)
  	return {items: items}

  afterRender: =>
  	console.log @options