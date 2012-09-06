Model = require "./model"
application = require '../application'
dashboardWidget = require '../views/dashboardWidget'

module.exports = class Dashboard extends Model
  urlRoot: -> "/api/dashboard"
  
  initialize: (attr) =>
    if attr.view
      @view = attr.view
    super()

  #widget: {id:'12345', name:'Name of widget', model:'/path/to/model', view:'/path/to/view'}
  parse: (response)=>
    for widget in response.widgets
      vi = @view.addSubview "widget_"+widget.id, dashboardWidget, '#widget_grid', {append:"widget_"+widget.id,widget:widget}
      vi.render()
      """
      if widget.view
        view = require "/views"+widget.view
      if widget.model
        model = require "/models"+widget.model
        model = new model {id:widget.id}
        model.fetch success:=>
          vi = @view.addSubView widget.id, dashboardWidget, '.dashboardGrid', {append:widget.id,id:widget.id,model:model}
          #vi = @view.addSubview widget.id, view, '.dashboardGrid', {append:widget.id,id:widget.id,model:model}
          vi.render()
      if !model && view
        #vi = @view.addSubview widget.id, view, '.dashboardGrid', {append:widget.id,id:widget.id}
        vi.render()
      """
      @
