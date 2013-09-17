[Application, 
 EditableTable,
 Tolerance] = [
  require('application'),
  require('views/table_editable'),
  require("models/tolerance")
]

module.exports = class ToleranceTable extends EditableTable

  ''' TODO '''
  '''
    Try creating a new row
    Try sorting on part Number
    Try deleting everything from a row
  '''

  ''' INIT '''
  
  initialize: =>
    Application.socket.on "message:backfill/complete/", @backfillComplete
    if !Application.subscriptions["backfill/complete/"]
      Application.subscriptions["backfill/complete/"] = Application.socket.emit 'subscribe', "backfill/complete/"
    
    super()

  # Append some variables to our table variables dict
  _variables: =>
    variables = super()
    variables.preHTML = '<div class="preheader">
              <div class="toggles"></div>
              <div class="buttonBar">
                <button data-color="yellow" class="createPart">New Part</button>
              </div>
            </div>' + variables.preHTML
    variables.newrows = []
    variables._model = Backbone.Model.extend()
    return variables

  _settings: =>
    settings = super()
    settings.styles.push('margin-top: 35px;')
    return settings

  _collection: =>
    collection = Application.measurements
    if collection.models.length
      for o,i in collection.models
        for y,x in @settings.columns
          if o.get('method') is y.data.key
            @settings.columns[x]['measurement_id'] = o.get('id')

    collection.on('reset', @_data)
    return collection

  _formatRow: (row) =>
    formatted = _.clone row.get('formatted')
    part = ""
    if formatted and formatted['metadata.Part Number']
      part = formatted['metadata.Part Number'] ? ''
    row = super(row)
    row.id = 'part-'+part
    row.data = ['data-part="'+part+'"']
    return row

  _formatData: (data) =>
    data = super(data)

    raw = {}
    for b,a in data
      if b.get('tolerance_list')?.length > 0
        for d,c in b.get('tolerance_list')
          for e,f of d.get('criteria')
            if !raw[f]
              raw[f] = {'metadata.Part Number':f}
            if !raw[f][b.get('method')]
              raw[f][b.get('method')] = []
            rule = _.clone d.get('rule')
            rule.measurement_id = b.get('id')
            rule.tolerance_id = d.get('id')
            raw[f][b.get('method')].push(rule)

    rows = []
    for a,b of raw
      row = {}
      for c,d of b
        for f,e in @settings.columns
          if f.data?.key
            location = f.data.key.split('.')
            if c is f.data.key
              k = c
            else if c is location[0]
              k = c
            else if c is location[1]
              k = c

        row[k] = undefined

        if typeof d is 'object'
          row[k] = {}
          for e,f of d
            if f.operator and f.value
              if f.measurement_id
                row[k]['measurement_id'] = f.measurement_id
              if f.operator is "<"
                row[k]['max'] = {value:f.value}
                if f.tolerance_id
                  row[k]['max'].tolerance_id = f.tolerance_id
              else if f.operator is ">"
                row[k]['min'] = {value:f.value}
                if f.tolerance_id
                  row[k]['min'].tolerance_id = f.tolerance_id

        else
          row[k] = d

      model = new @variables._model({formatted:row})
      rows.push(model)
    
    return rows

  # Takes cell data, returns formatted cell content/html
  _formatCell: (settings, value) =>
    cell = {title:'', html:'', data:[]}
    tols = ['min', 'max']

    for i,o of settings.data
      cell.data.push('data-'+i+'="'+o+'"')
    
    if !value
      value = {}
      for y,x in @settings.columns
        if y.data.key is settings.data.key
          value['measurement_id'] = y.measurement_id
      value['min'] = {'value':''}
      value['max'] = {'value':''}

    if typeof value is 'object'
      value['min'] = value['min'] ? {value:''}
      value['max'] = value['max'] ? {value:''}
      for b,a in tols
        if b
          placeholder = b
        v = ''
        if value[b] and value[b].value
          v = value[b].value
        else
          v = ''
        args = {
          placeholder: placeholder
          type: 'text'
          value: v
        }
        if value.measurement_id
          args['data-measurement-id'] = value.measurement_id
        if value[b]?.tolerance_id
          args['data-tolerance-id'] = value[b].tolerance_id
        if b
          args['data-operator'] = b
        cell.html += "<input "
        for k,v of args
          cell.html += k + '="' + v + '" '
        cell.html += "/>"
    else 
      cell.html = value

    cell.raw = value
    cell.classes = value.classes

    return cell

  saveCleanup: (t=undefined, o=undefined) =>
    tid = t.get('id')
    # Write the tolerance id to the UI so we can just write directly now.
    if tid
      @saveInfo.target.attr('data-tolerance-id', tid)
    # Save the new tolerance to the measurement 
    if @saveInfo.measurement_id
      measurement = Application.measurements.get(id=@saveInfo.measurement_id)
      measurement.attributes.tolerance_list.push(o)
      measurement.save()

  saveCell: (obj) =>
    @saveInfo = {}
    if obj.tolerance_id and obj.measurement_id
      @saveInfo['measurement_id'] = obj.measurement_id
      @saveInfo['target'] = obj.target
      tolerance = Application.tolerance_list.where({id:obj.tolerance_id})
      console.log tolerance
      for o,i in tolerance
        o.attributes.rule.value = obj.value
        o.attributes.id = obj.tolerance_id
      o.save({}, {wait:true, success:@saveCleanup})
    else if obj.measurement_id
      @saveInfo['measurement_id'] = obj.measurement_id
      @saveInfo['target'] = obj.target
      criteria = {}
      if obj.part
        criteria.part_number = obj.part
      rule = {}
      if obj.operator
        if obj.operator is "min"
          rule.operator = ">"
        if obj.operator is "max"
          rule.operator = "<"
      if obj.value
        rule.value = obj.value
      t = new Tolerance({criteria:criteria, rule:rule})
      t.save({}, {wait:true, success:@saveCleanup})

  saveRow: (options) =>
    if options and options.part
      id = options.part
      @newRows.push(id)
      @updateData()

  showNewRowModal:(m='') =>
    SimpleSeer.modal.show
      title: "New Tolerance"
      message: m
      submitText: 'Save'
      cancelText: 'Cancel'
      throbber: false
      submit:(results) => @saveRow(results)
      form: [{id: "part", type: "text", label: "Part Number"}]
    return 0

  events: =>
    parent_events = super()
    events = { "click .buttonBar .createPart":"addRow", 'change input[type="text"]':'changeCell' }
    _.extend parent_events, events

  addRow: =>
    @showNewRowModal('<p class="center">Enter in a Part Number for the new tolerance.</p>')

  backfillComplete: =>
    # TODO: we should give some kind visual feedback based on the job thats currently running
    return

  changeCell:(e) =>
    target = $(e.target)
    id = target.parents('tr').attr('id')
    part = target.parents('tr').data('part')
    operator = target.data('operator')
    measurement_id = target.data('measurement-id')
    tolerance_id = target.data('tolerance-id')
    value = target.val()
    obj = {}
    if target then obj.target = target
    if id then obj.id = id
    if part then obj.part = part
    if operator then obj.operator = operator
    if value then obj.value = value
    if measurement_id then obj.measurement_id = measurement_id
    if tolerance_id then  obj.tolerance_id = tolerance_id
    
    @saveCell(obj)