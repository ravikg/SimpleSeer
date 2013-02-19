Model = require "./model"
application = require 'application'
dashboardWidget = require 'views/core/dashboardWidget'

module.exports = class Dashboard extends Model
  urlRoot: -> "/api/dashboard"
  loaded: false
  
  initialize: =>
    if @attributes.view
      @view = @attributes.view
      delete @attributes.view
    super()

  fetch:(options={})=>
    if !options.success?
      options.success = @loadElements
    super(options)
    
  loadElements: =>
    if @view
      @locked = @get('locked')
      @view.clearSubviews()
      for widget in @attributes.widgets
        vi = @view.addSubview "widget_"+widget.id, dashboardWidget, '#widget_grid', {append:"widget_"+widget.id,widget:widget}
        vi.render()
      @loaded = true

