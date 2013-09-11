Array.prototype.where = (dict) ->
  return _.where(this, dict)

Array.prototype.findWhere = (dict) ->
  return _.where(this, dict)[0]