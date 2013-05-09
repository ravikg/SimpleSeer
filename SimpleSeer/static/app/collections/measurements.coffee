Collection = require "./collection"
Measurement = require "../models/measurement"

module.exports = class Measurements extends Collection
  url: "/api/measurement"
  model: Measurement
  toSave: []
  saveTimeout: undefined
  rows: undefined

  getTable:(key,cols)=>

    columns = {}
    rows = {}
    
    for o in @models
      _l = o.get("label")
      if cols
        if _l in cols
          columns[o.get("id")] = _l
      else
        columns[_l] = o.get("id")
      _t = o.get("tolerances")
      if _t.length > 0
        for item in _t
          if !rows[item.criteria[key]]?
            rows[item.criteria[key]] = {}
          if !rows[item.criteria[key]][_l]?
            rows[item.criteria[key]][_l] = []
          rows[item.criteria[key]][_l].push {id:o.get("id"), operator:item.rule.operator, value:item.rule.value}

    return {columns:columns,rows:rows}

  setTable:(data) =>

    key = data.title
    tolerance = {'rule' : {}, 'criteria' : {}}
    if data.id
      tolerance.criteria['Part Number'] = data.id
    if data.subkey
      if data.subkey == "min"
        tolerance.rule.operator = '<'
      else if data.subkey == "max"
        tolerance.rule.operator = '>'
    if data.value
      tolerance.rule.value = data.value

    if tolerance.criteria['Part Number'] and tolerance.rule.operator
      set = @where({'label' : key})
      for o in set
        isChanged = false
        for i,t of o.get("tolerances")
          if t.rule.operator == tolerance.rule.operator and _.isEqual t.criteria, tolerance.criteria
            if tolerance.rule.value != ""
              o.attributes.tolerances[i] = tolerance
              isChanged = true
            else
              o.attributes.tolerances.splice(i,1)
              isChanged = true
        if !isChanged
          o.attributes.tolerances.push tolerance
          isChanged = true
        if isChanged
          @setSave(o)
          #o.save()

    return

  setSave: (o) =>
    i = 0
    _.each @toSave, (meas) =>
      if meas.cid == o.cid
        @toSave.splice(i,1)
      i++
    @toSave.push(o)
    if @timeout
      @clearSave()
    @timeout = setTimeout(@doSave, 3000);

  doSave: =>
    _.each @toSave, (meas) =>
      meas.save()

  clearSave: =>
    clearTimeout(@timeout)