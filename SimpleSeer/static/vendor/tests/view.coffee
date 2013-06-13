View = require("views/core/view")
SubView = require("views/core/subview")

describe "View", ->
  v = undefined
  parent = undefined

  setupTest = (o={}) ->
    v = new View(o)
    parent = $("<div/>")
    parent.append(v.el)

  beforeEach -> setupTest()
  afterEach -> v.remove()

  it "should extend Backbone.View", ->
    expect(v instanceof Backbone.View).toBe true

  describe "#events", ->
    evt = "event-0"
    fn = jasmine.createSpy()

    it "should be able to add custom events", ->
      v.addCustomEvent(evt, fn)
      expect(v.events[evt]).toEqual(fn)

    it "should be able to fire custom events", ->
      v.customEvent(evt)
      expect(fn).toHaveBeenCalled()

  describe "#context", ->
    it "should set application context if context passed in options", ->
      v.remove()
      spyOn(SimpleSeer, 'loadContext')
      setupTest({context: "blank"})
      expect(SimpleSeer.loadContext).toHaveBeenCalledWith("blank")

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
