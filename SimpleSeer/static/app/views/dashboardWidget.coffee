application = require '../../../application'
SubView = require './subview'
template = require './templates/dashboardWidget'

module.exports = class Dashboard extends SubView
  name:''
  cols:1
  template:template
  tagName:'li'
  className:'widget_container'
  
  initialize: (attr) =>
    super(attr)
    @htmltags["cols"] = 1
    @htmltags["style"] = "width: 100%"
    #style="width: {{width}}%;{{#if boxHeight}} height:{{boxHeight}}px;{{/if}}"
    @widget = attr.widget
      
  render: =>
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
    cw = 100/@options.parent.cols
    _w = {}
    _w["id"] = @widget.id
    _w["cols"] = @widget.cols
    _w["title"] = @widget.name
    _w["width"] = cw*@widget.cols
    #if o.height
    #  _w["boxHeight"] = o.height + 10
    #  _w["height"] = o.height
    return _w

    
