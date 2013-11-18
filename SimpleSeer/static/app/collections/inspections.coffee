[Collection, Inspection] = [
  require("collections/collection"),
  require("models/inspection")
]

module.exports = class Inspections extends Collection
  url: "/api/frameset"
  model: Inspection
  