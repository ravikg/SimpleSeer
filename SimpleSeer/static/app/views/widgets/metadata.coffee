[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/metadata")
  require("models/frame")
]

module.exports = class MetaData extends SubView
  template: Template
  selected: null
  frames: []

  select: (params) =>
    if params and params[@key]?
      @selected = params[@key]
      console.log @selected

  receive: (data) =>
    @frames = data
    @render()

  getRenderData: =>
    fields: [{'key':'TPM', 'value':5434583722}, {'key':'VIN', 'value':'2HNYD18213H553107'}, {'key':'DATE', 'value':'11/13/13'}, {'key':'TIME', 'value':'12:30:14'}]