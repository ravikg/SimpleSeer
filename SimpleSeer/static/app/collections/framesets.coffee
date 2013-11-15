[Collection, FrameSet] = [
  require("collections/collection"),
  require("models/frameset")
]

module.exports = class FrameSets extends Collection
  url: "/api/frameset"
  model: FrameSet
  