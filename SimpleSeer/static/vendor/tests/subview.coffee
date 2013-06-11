window.subviewTest = =>
  View = require("views/core/view")
  SubView = require("views/core/subview")

  describe "SubView", ->
    v = new SubView()

    it "should extend View", ->
      expect(v instanceof View).toBe true

    it "should not have rendered yet", ->
      expect(v.firstRender).toBe true

    it "should set property firstRender to false after first render", ->
      v.render()
      expect(v.firstRender).toBe false

    it "should be able to append a subview", ->
      title = "subview-0"
      v.addSubview title, SubView
      expect(v.subviews[title]).toBeDefined()

    it "should be able to remove a subview", ->
      v.clearSubviews()
      expect(JSON.stringify(v.subviews)).toEqual "{}"
