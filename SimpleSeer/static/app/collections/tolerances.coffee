[Collection, Tolerance] = [
  require("collections/collection"),
  require("models/tolerance")
]

module.exports = class Tolerances extends Collection
  url: "/api/tolerance"
  model: Tolerance