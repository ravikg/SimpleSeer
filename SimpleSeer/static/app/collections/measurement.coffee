[Collection, Measurement] = [
  require("collections/collection"),
  require("models/measurement")
]

module.exports = class Measurements extends Collection
  url: "/api/measurement"
  model: Measurement