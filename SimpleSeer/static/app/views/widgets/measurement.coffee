[Template, SubView, application] = [
  require("views/widgets/templates/measurement"),
  require("views/core/subview"),
  require("application")
]

module.exports = class MeasurementSelector extends SubView
  template: Template
  
  initialize: =>
    @callbacks = []
    if @options.params.default?
      @default = @options.params.default
    SimpleSeer.controlSelector = @
  
  afterRender: =>
    super()
    @$("select").chosen({
      no_results_text: "No results matched"
      allow_single_deselect: true
    }).change((event, ui) =>
      if (ui is undefined) then (ui = {selected: "_"})
      v = ui.selected
      @setValue(v, true)
    )
    @$el.addClass "filter_widget"
    return
  
  setValue:(val) =>
    for fn in @callbacks
      fn(val)
      
  _set:(val) =>
    @$("select").val(val).trigger("liszt:updated")
    
  onChange:(fn) =>
    @callbacks.push fn
  
  getRenderData: =>
    return { measurements: SimpleSeer.measurements.models, default: @default }