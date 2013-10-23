Collection = require "./collection"
Tolerance = require "../models/tolerance"

module.exports = class Tolerance_list extends Collection
  url: "/api/tolerance"
  model: Tolerance
