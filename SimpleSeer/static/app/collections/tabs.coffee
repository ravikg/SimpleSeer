[Model, Collection] = [
	require("models/tab"),
	require("collections/collection")
]

module.exports = class Tabs extends Collection
  url: "/api/tabcontainer"
  model: Model