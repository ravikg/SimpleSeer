Model = require "./model"

module.exports = class OLAP extends Model
  urlRoot: "/api/chart"
  shift: false
  
  save:(a,b,c)=>
    console.log a,b,c
    console.log @attributes.dataMap
    #super()
    console.log @attributes.dataMap
    

  setColor:(title, value) =>
    if title == "chartColor"
      @set("color", value)
    if title == "chartLabelColor"
      @set("labelColor", value)
    if title == "chartTitleColor"
      @set("titleColor", value)
    return  

  pointStack: () ->
    stack : []
    add: (d,shift=@shift) ->
      #_a = {x:d.x,y:d.y,id:d.id}
      @.stack.push d
      if shift
        p = @.stack.shift()
      return p
    set: (d) ->
      @stack = []
      for o in d
        @.add o, false
    buildData: (data) =>
      if !data
        data = @.view.stack.stack
      dd = []
      if @.attributes.labelmap
        for i of @.attributes.labelmap
          dd[i] = {x:i,id:i,y:0}
          if @.attributes.colormap && @.attributes.colormap[i]
            dd[i].color = @.attributes.colormap[i]
      _stk = []
      for p in data
        if dd[p.id]
          p = dd[p.id]
          p.y++
        else
          p.y = 1
        dd[p.id] = p
        _stk.push p
      _dd = []
      for i in dd
        if i
          _dd.push i
      @.view.stack.set _stk
      return _dd
      
  parse: (response) =>
    _ormMap = {root:{},results:{}}
    for o in response.dataMap
      _p = o.indexOf('.')
      if _p > 0
        _ormMap['results'][o] = o.substring(0, _p)
        #response.dataMeasurementsMap.push o.substring(0, _p)
      else
        _ormMap['root'][o] = o
    #response.dataMap = dm
    response._ormMap = _ormMap
    super response
