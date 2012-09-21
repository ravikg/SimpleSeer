SubView = require '../subview'
application = require '../../application'
ChartView = require '../chart'

module.exports = class _filter extends SubView
  value:null
  className:'filter_widget'
  initialize: () =>
    @options.params.name = (@options.params.field_name+'-'+@options.params.format).replace(/[^a-z0-9_\-]/gi,'_')
    super()
    @collection = @options.collection || null
    if !application.filterData[@options.params.name]?
      application.filterData[@options.params.name] = $.ajax '/getFilter/'+@options.params.type+'/'+@options.params.field_name+'/'+@options.params.format, {dataType:'json', async:false}
    _ret = application.filterData[@options.params.name]
    @options.params.constraints = $.parseJSON _ret.responseText
    @options.subselector = ''
    @
  
  afterRender: ()=>
    @$el.addClass(@className)
    super()
  
  setValue: (v, send=false) =>
    @collection.skip = @collection._defaults.skip
    #@collection.limit = @collection._defaults.limit
    
    if v == ''
      v = null
    @value = v
    if send
      @collection.fetch()
    
  getValue: () =>
    @value

  toJson: () =>
    false

      
