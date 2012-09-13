application = require '../../../application'
SubView = require './subview'
template = require './templates/dashboardWidget'

module.exports = class DashboardWidget extends SubView
  name:''
  template:template
  tagName:'li'
  className:'widget_container'
  
  initialize: (attr) =>
    super(attr)
    #style="width: {{width}}%;{{#if boxHeight}} height:{{boxHeight}}px;{{/if}}"
    @widget = attr.widget

  events:
    'click .close' : 'remove'
    'click .config' : 'config'
    
  remove: =>
    for i,o of @subviews
      for n,w of @options.parent.model.attributes.widgets
        if w.id == o.id
          @options.parent.model.attributes.widgets.splice(n,1)
    @options.parent.model.save()
    super()

  config: =>
    if @subviews[@options.widget.id] && @subviews[@options.widget.id].model
      @options.parent.chart = @subviews[@options.widget.id].model
      @options.parent.toggleBuilder()

  render: =>
    cw = 100/@options.parent.cols
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

    
