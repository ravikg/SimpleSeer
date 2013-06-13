View = require("views/core/view")
SubView = require("views/core/subview")

describe "SubView", ->
  v = parent = undefined
  beforeEach ->
    v = new SubView()
    parent = $("<div/>")
    parent.append(v.el)

  afterEach ->
    v.remove()

  it "should extend View", ->
    expect(v instanceof View).toBe true

  describe "#events", ->
    it "should ", ->
      expect()

  describe "#rendering", ->
    it "should not have rendered yet", ->
      expect(v.firstRender).toBe true

    it "should set property firstRender to false after first render", ->
      v.render()
      expect(v.firstRender).toBe false

    it "should unhook from the DOM on remove", ->
      v.remove()
      expect(v.el.parentNode).toBeNull()

  describe "#subviews", ->
    sv = undefined
    beforeEach ->
      sv = v.addSubview "subview-0", SubView

    it "should be able to append a subview", ->
      expect(v.subviews["subview-0"]).toBeDefined()

    it "should be able to remove a subview", ->
      v.clearSubviews()
      expect(JSON.stringify(v.subviews)).toEqual "{}"

    it "should destroy all subviews on remove", ->
      v.remove()
      expect(JSON.stringify(v.subviews)).toEqual "{}"
