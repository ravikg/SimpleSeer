Modal = require("views/core/modal")
View = require("views/core/view")

describe "Modal", ->
  it "should extend View", ->
    m = new Modal()
    expect(m instanceof View).toBe true

  describe "#show", ->
    m = new Modal()
    el = m.$el
    options =
      title: "Test Title"
      message: "Test Message"
      success: jasmine.createSpy("dummySuccess")
      error: jasmine.createSpy("dummyError")
    m.show options

    it "should display a title", ->
      expect(el.find(".title").html()).toEqual options.title

    it "should display a message", ->
      expect(el.find(".message").html()).toEqual options.message


  describe "#onSuccess", ->
    m = new Modal()
    el = m.$el
    options =
      title: "Test Title"
      message: "Test Message"
      success: jasmine.createSpy("dummySuccess")
      cancel: jasmine.createSpy("dummyError")
    m.show options
    m.onSuccess()

    it "should run the success callbacks", ->
      expect(options.success).toHaveBeenCalled()

    it "should not run the error callbacks", ->
      expect(options.cancel).not.toHaveBeenCalled()

  describe "#onCancel", ->
    m = new Modal()
    el = m.$el
    options =
      title: "Test Title"
      message: "Test Message"
      success: jasmine.createSpy("dummySuccess")
      cancel: jasmine.createSpy("dummyError")
    m.show options
    m.onCancel()

    it "should not run the success callbacks", ->
      expect(options.success).not.toHaveBeenCalled()

    it "should run the error callbacks", ->
      expect(options.cancel).toHaveBeenCalled()
