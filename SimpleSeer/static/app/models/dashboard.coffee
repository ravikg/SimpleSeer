Model = require "./model"
application = require '../application'
dashboardWidget = require '../views/dashboardWidget'

module.exports = class Dashboard extends Model
  urlRoot: -> "/api/dashboard"
  loaded: false
  
  initialize: (attr) =>
    if attr.view
      @view = attr.view
    if @attributes.view
      delete @attributes.view
    super()

  #widget: {id:'12345', name:'Name of widget', model:'/path/to/model', view:'/path/to/view'}
  parse: (response)=>
    if !@loaded
      @loadElements(response)
    return response
    
  loadElements: (response) =>
    for widget in response.widgets
      vi = @view.addSubview "widget_"+widget.id, dashboardWidget, '#widget_grid', {append:"widget_"+widget.id,widget:widget}
      vi.render()
    @loaded = true

