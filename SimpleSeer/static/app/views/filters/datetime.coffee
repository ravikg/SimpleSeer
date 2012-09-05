_filter = require './filter'
template = require './templates/datetime'
application = require 'application'

module.exports = class DateTimeFilterView extends _filter
  id: 'datetime-filter-view'
  template: template
  _vals: []

  initialize: () =>
    super()
    tf = new moment(@options.params.constraints.min)
    tt = new moment(@options.params.constraints.max)
    @options.params.constraints.min = tf
    @options.params.constraints.max = tt
    @_vals['from'] = tf.valueOf()
    @_vals['to'] = tt.valueOf()
    return @
    
  displayPrettyDate:(s, e) =>
    @$el.find('input[name=time_range]').attr("value", "#{SimpleSeerDateHelper.prettyDate(s)} - #{ SimpleSeerDateHelper.prettyDate(e)}")
    return

  afterRender: =>
    startDate = new Date(@options.params.constraints.min-application.timeOffset)
    startDate.setHours(0);
    startDate.setMinutes(0);
    startDate.setSeconds(0);
    
    endDate = new Date(@options.params.constraints.max-application.timeOffset)
    endDate.setDate(endDate.getDate() + 1)
    endDate.setHours(0);
    endDate.setMinutes(0);
    endDate.setSeconds(0);
    
    tf = @$el.find('input[name=time_range]').datetimerange
      timeFormat: "h:mm tt"
      onUpdate: @setValue
      ampm: true
      startDate: startDate
      endDate: endDate
      
    @displayPrettyDate(startDate, endDate)
    super()
    return

  setValue:(e, ui) =>
    @displayPrettyDate(ui.startDate, ui.endDate)
    
    date_from = new moment(ui.startDate)
    date_from.add('ms', application.timeOffset)
    @_vals["from"] = date_from.valueOf()
    date_to = new moment(ui.endDate)
    date_to.add('ms', application.timeOffset)
    @_vals["to"] = date_to.valueOf()    

    super([@_vals["from"], @_vals["to"]], true)
    return
      

  getRenderData: () =>
    return @options.params
    
  toJson: () =>
    vals = @getValue()
    if vals
      retVal = 
        type:@options.params.type
        lt:vals[1]
        gt:vals[0]
        name:@options.params.field_name
    return retVal
