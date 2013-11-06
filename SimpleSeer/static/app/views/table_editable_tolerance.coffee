[Application, 
 EditableTable,
 Tolerance] = [
  require('application'),
  require('views/table_editable'),
  require("models/tolerance")
]

module.exports = class ToleranceTable extends EditableTable

  ''' INIT '''
  
  initialize: =>
    Application.socket.on "message:backfill/complete/", @backfillComplete
    if !Application.subscriptions["backfill/complete/"]
      Application.subscriptions["backfill/complete/"] = Application.socket.emit 'subscribe', "backfill/complete/"
    
    super()

  backfillComplete: =>
    # TODO: we should give some kind visual feedback based on the job thats currently running
    return

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
    settings.default_tolerances = @options.default_tolerances ? []
    settings.measurements = {}
    for m in Application.measurements.models
      settings.measurements[m.get('id')] = m.get('method')
      for y,x in settings.columns
        if y.data.key == m.get('method')
          settings.columns[x]['measurement_id'] = m.get('id')
    return settings



  ''' GETTING / SETTING DATA '''

  _collection: =>
    collection = new Backbone.Collection([], {
      model: @settings.model
    })
    collection.url = @settings.url
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
      key = b.get('key')

      if key
        criteria = b.get('criteria')
        measurement_id = b.get('measurement_id')

        if measurement_id

          if @settings.measurements[measurement_id]
            method = @settings.measurements[measurement_id]

            if !raw[key]
              raw[key] = {'metadata.Part Number':key}

            if !raw[key][method]
              raw[key][method] = []

            rule = _.clone b.get('rule')
            rule.measurement_id = measurement_id
            rule.tolerance_id = b.get('id')

            raw[key][method].push(rule)

    # Insert the new rows
    nr = _.clone @variables.newrows
    @variables.newrows = []
    newrow = null
    for b,a in nr
      if raw[b] and typeof(raw[b]) == 'string'
        # Do Nothing
        newrow = b
      else if raw[b] and typeof(raw[b]) == 'object'
        # Do nothing
        newrow = b
        Application.alert("Part already exists", 'warning')
        $('#messages .alert').last().delay(5000).fadeOut('fast')
      else
        raw[b] = {'metadata.Part Number':b}
        @variables.newrows.push(b)
        newrow = b

    if newrow != null
      sorted = []
      for a,b of raw
        sorted.push(a)

      sorted.sort()

      i = 1
      for a,b in sorted
        if a == newrow
          @variables.highlight = newrow
          @variables.navigateId = i
        i++

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
      send = {formatted:row, metadata:{}}
      send.metadata[@settings.columns[0].title] = row[@settings.columns[0].data.key]
      model = new @variables._model(send)
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

    notEmpty = false

    if typeof value is 'object'
      value['min'] = value['min'] ? {value:''}
      value['max'] = value['max'] ? {value:''}
      
      if value['min'].value or value['max'].value
        notEmpty = true

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
    cell.classes = value.classes ? []
    if settings.classes
      for o,i in settings.classes
        cell.classes.push(o)
    if notEmpty
      cell.classes.push('notEmpty')

    return cell


  ''' EVENT HANDLING '''

  events: =>
    parent_events = super()
    events = { "click .buttonBar .createPart":"_addRow", 'change input[type="text"]':'_changeCell' }
    _.extend parent_events, events

  _addRow: =>
    @_modal('<p class="center">Enter in a Part Number for the new tolerance.</p>')

  _changeCell:(e) =>
    target = $(e.target)
    id = target.parents('tr').attr('id')
    part = target.parents('tr').data('part')
    operator = target.data('operator')
    measurement_id = target.data('measurement-id')
    tolerance_id = target.data('tolerance-id')
    value = target.val()
  
    # Highlight new cells with data
    values = []
    target.parent('span').children('input').each ->
      v = $(this).val()
      if v or String(v) == "0"
        values.push(v)
    if values.length
      target.parents('.td').addClass('notEmpty')
    else
      target.parents('.td').removeClass('notEmpty')


    obj = {}
    if target then obj.target = target
    if id then obj.id = id
    if part then obj.part = part
    if operator then obj.operator = operator
    if value then obj.value = value
    if measurement_id then obj.measurement_id = measurement_id
    if tolerance_id then  obj.tolerance_id = tolerance_id
    
    @saveCell(obj)

  saveCleanup: (t=undefined, o=undefined) =>
    tid = t.get('id')
    # Write the tolerance id to the UI so we can just write directly now.
    if tid
      @saveInfo.target.attr('data-tolerance-id', tid)

  destroyCleanup: (t=undefined, o=undefined) =>
    return

  saveCell: (obj) =>
    @saveInfo = {}
    if obj.tolerance_id and obj.measurement_id
      @saveInfo['target'] = obj.target
      tolerance = @collection.get(obj.tolerance_id)
      if !obj.value
        tolerance.destroy({success:@destroyCleanup})
        Application.alert('Tolerance Deleted', "success")
        $('#messages .alert').last().delay(3000).fadeOut('fast')
      else
        tolerance.attributes.rule.value = obj.value
        delete(tolerance.attributes.formatted)
        tolerance.save({}, {wait:true, success:@saveCleanup})
        Application.alert('Tolerance Updated', "success")
        $('#messages .alert').last().delay(3000).fadeOut('fast')

    else if obj.measurement_id
      @saveInfo['measurement_id'] = obj.measurement_id
      @saveInfo['target'] = obj.target
      criteria = {}
      if obj.part
        criteria['Part Number'] = String(obj.part)
        key = String(obj.part)
      else
        key = ""
      rule = {}
      if obj.operator
        if obj.operator is "min"
          rule.operator = ">"
        if obj.operator is "max"
          rule.operator = "<"
      if obj.value
        rule.value = String(obj.value)
      t = new Tolerance({criteria:criteria, rule:rule, key:key, measurement_id:obj.measurement_id})
      t.save({}, {wait:true, success:@saveCleanup})
      Application.alert('Tolerance Created', "success")
      $('#messages .alert').last().delay(3000).fadeOut('fast')

  _saveRow: (options) =>
    if options and options.part
      id = options.part
      @variables.newrows.push(id)
      @variables.cleardata = true
      @variables.clearrows = true
      @variables.init = 0
      @collection.fetch()
      #@_data()


  _modal:(m='') =>
    SimpleSeer.modal.show
      title: "New Tolerance"
      message: m
      submitText: 'Save'
      cancelText: 'Cancel'
      throbber: false
      submit:(results) => @_saveRow(results)
      form: [{id: "part", type: "text", label: "Part Number"}]
    return 0