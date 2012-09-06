Model = require "./model"
application = require '../application'

module.exports = class Dashboard extends Model
  urlRoot: -> "/api/dashboard"
  
  initialize: (attr) =>
    if attr.view
      @view = attr.view
      console.log @view
    super()

  #widget: {id:'12345', name:'Name of widget', model:'/path/to/model', view:'/path/to/view'}
  parse: (response)=>
    for widget in response.widgets
      console.dir widget
      if widget.view
        console.info "loading view /views"+widget.view
        view = require "/views"+widget.view
      if widget.model
        console.info "loading model /models"+widget.model
        model = require "/models"+widget.model
        model = new model {id:widget.id}
        model.fetch  success:=>
          vi = @view.addSubview widget.id, view, '.dashboardGrid', {append:widget.id,id:widget.id,model:model}
          vi.render()
      if !model && view
        console.info 'loading view without model'
        vi = @view.addSubview widget.id, view, '.dashboardGrid', {append:widget.id,id:widget.id}
        vi.render()
        #@widgets.push new view()
