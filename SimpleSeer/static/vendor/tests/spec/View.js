var View = require("views/core/view")
var SubView = require("views/core/subview")

describe("View", function() {

  var v = new View();

  it("should extend Backbone.View", function() {
    expect(v instanceof Backbone.View).toBe(true);
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
  });

  it("should be able to remove a subview", function() {
    v.clearSubviews()
    expect(JSON.stringify(v.subviews)).toEqual("{}")
  });

});
