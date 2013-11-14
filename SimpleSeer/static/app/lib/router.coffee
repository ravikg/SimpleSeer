module.exports = class Router extends Backbone.Router

  routes: =>
    "": "tab"
    "tab/:name": "tab"
    "tab/:name/:query": "tab"
    "page/:name": "page"

  tab:(name=undefined, query="") =>
    # TODO: query will set up the filter bar
    # and widget states.
    Application.pages.close(false)
    if name?
      Application.tabs?.loadTabByName(name)
    else
      Application.tabs?.loadDefaultTab()


  page:(name=undefined) =>
    if name?
      Application.pages?.loadPageByName(name)
    else
      Application.tabs?.loadDefaultTab()
    