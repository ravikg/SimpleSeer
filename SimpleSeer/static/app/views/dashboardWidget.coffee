application = require '../../../application'
SubView = require './subview'
template = require './templates/dashboardWidget'

module.exports = class DashboardWidget extends SubView
  name:''
  cols:1
  template:template
  tagName:'li'
  className:'widget_container'
  
  initialize: (attr) =>
    super(attr)
    #style="width: {{width}}%;{{#if boxHeight}} height:{{boxHeight}}px;{{/if}}"
    @widget = attr.widget
      
  render: =>
    cw = 100/@options.parent.cols
    #@htmltags["cols"] = @widget.cols
    @htmltags["style"] = "width: "+(cw*@widget.cols)+"%"
    super()
    if @widget.view
      view = require "/views"+@widget.view
    if @widget.model
      model = require "/models"+@widget.model
      model = new model {id:@widget.id}
      model.fetch success:=>
        vi = @addSubview @widget.id, view, "#"+@widget.id, {id:@widget.id,model:model}
        vi.render()
#    if !model && view
#      #vi = @view.addSubview widget.id, view, '.dashboardGrid', {append:widget.id,id:widget.id}
#      vi.render()

  getRenderData: =>
    widgets = []
    _w = {}
    _w["id"] = @widget.id
    _w["cols"] = @widget.cols
    _w["title"] = @widget.name
    #if o.height
    #  _w["boxHeight"] = o.height + 10
    #  _w["height"] = o.height
    return _w

    
