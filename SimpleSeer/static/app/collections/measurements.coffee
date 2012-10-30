Collection = require "./collection"
Measurement = require "../models/measurement"

module.exports = class Measurements extends Collection
  url: "/api/measurement"
  model: Measurement
  
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
  #setTable:(rowKey,valKey,where,operator)=>
  setTable:(data)=>
  	#if data.criteria["Part Number"].value() doesnt exist
  	#  create tolerance in o
  	#if i not found, return (error)
    for key, tolerance of data
      set = @where({ 'label':key })
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
          o.save()
        
    return
    o = @where({ 'label':valKey })
    t = o[0].get("tolerances")
    set = false
    for _t in t
      if _t.criteria
        set = true            