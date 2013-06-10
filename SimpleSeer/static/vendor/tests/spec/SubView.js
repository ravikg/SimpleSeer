var View = require("views/core/view")
var SubView = require("views/core/subview")

describe("SubView", function() {

  var v = new SubView();

  it("should extend View", function() {
    expect(v instanceof View).toBe(true);
  });

  it("should not have rendered yet", function() {
    expect(v.firstRender).toBe(true);
  });

  it("should set property firstRender to false after first render", function() {
    v.render()
    expect(v.firstRender).toBe(false);
  });

  it("should be able to append a subview", function() {
    title = "subview-0"
    v.addSubview(title, SubView)
    expect(v.subviews[title]).toBeDefined()
  })

  it("should be able to remove subviews", function() {
    v.clearSubviews()
    expect(JSON.stringify(v.subviews)).toEqual("{}")
  })

  /*it("should respect tagName and className attributes", function() {
    title = "subview-1"
    tag = "p"
    clas = "test"

    v.addSubview(title, SubView, {
      selector: document.body,
      append: "foo",
      tagName: tag,
      className: clas
    })

    v.render()

    expect(false).toBeTruthy()
  })*/

});
