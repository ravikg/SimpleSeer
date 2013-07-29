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
      expect(el.html().indexOf(options.message) >= 0).toBe(true)

  describe "#submit", ->
    m = new Modal()
    el = m.$el
    options =
      title: "Test Title"
      message: "Test Message"
      submit: jasmine.createSpy("dummySuccess")
      cancel: jasmine.createSpy("dummyError")
    m.show options
    m.handleSubmit()

    it "should run the submit callbacks", ->
      expect(options.submit).toHaveBeenCalled()

    it "should not run the cancel callbacks", ->
      expect(options.cancel).not.toHaveBeenCalled()

  describe "#cancel", ->
    m = new Modal()
    el = m.$el
    options =
      title: "Test Title"
      message: "Test Message"
      submit: jasmine.createSpy("dummySuccess")
      cancel: jasmine.createSpy("dummyError")
    m.show options
    m.handleCancel()

    it "should not run the submit callbacks", ->
      expect(options.submit).not.toHaveBeenCalled()

    it "should run the cancel callbacks", ->
      expect(options.cancel).toHaveBeenCalled()

  describe "#buttons", ->
    m = new Modal()
    el = m.$el
    options =
      title: "Test Title"
      message: "Test Message"
      buttons: [
        {text: "Enter", action: "enter", color: "yellow", fn: jasmine.createSpy("dummyEnter") }
        {text: "Exit", action: "exit", color: "blue", fn: jasmine.createSpy("dummyExit") }
      ]
    m.show options

    it "should display custom buttons", ->
      expect(el.find("button[action=enter]").length).toEqual 1
      expect(el.find("button[action=exit]").length).toEqual 1

    it "should run the custom callbacks on click", ->
      el.find("button[action=enter], button[action=exit]").click()
      expect(options.buttons[0].fn).toHaveBeenCalled()
      expect(options.buttons[1].fn).toHaveBeenCalled()

  describe "#form", ->
    testValue = "1340958"
    m = new Modal()
    el = m.$el
    options =
      title: "Test Title"
      message: "Test Message"
      submit: jasmine.createSpy("dummySuccess")
      cancel: jasmine.createSpy("dummyError")
      form: [
        {id: "name", label: "Name", type: "text", value: testValue}
      ]
    m.show options
    m.handleSubmit()

    it "should pass results to the callbacks", ->
      expect(options.submit.mostRecentCall.args[0].name).toEqual testValue
