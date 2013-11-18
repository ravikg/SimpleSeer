[View, Template] = [
  require("views/view"),
  require("./templates/page")
]

# Note: When extending this class, please
# follow the naming convention <Custom>Page
# where <Cutsom> can be anything not including
# the work Page. This straps the styles on nicely.

module.exports = class Page extends View
  template: Template

  events: =>
    "click .close": "close"

  initialize: =>
    super()
    @title = ""

  getRenderData: =>
    return { title: @title }

  close: =>
    Application.pages.close()

  _close: =>
    @remove()
