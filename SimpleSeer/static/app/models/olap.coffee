[ Model ] = [ require("models/model") ]

module.exports = class OLAP extends Model
  urlRoot: "/api/chart"
  shift: false

  parse: (response) =>
    _ormMap = {root: {}, results: {}}
    for o in response.dataMap
      _p = o.indexOf('.')
      if _p > 0
        _ormMap['results'][o] = o.substring(0, _p)
      else
        _ormMap['root'][o] = o
    response._ormMap = _ormMap
    super response