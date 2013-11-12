[Model, Collection] = [
	require("models/tab"),
	require("collections/collection")
]

module.exports = class TabCollection extends Collection
  url: "/api/tabcontainer"
  model: Model