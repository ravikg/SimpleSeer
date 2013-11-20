module.exports = class Router extends Backbone.Router

  routes: =>
    "": "tab"
    "tab/:name": "tab"
    "tab/:name/": "tab"
    "tab/:name/:query": "tab"
    "page/:name": "page"

  tab:(name, query) =>
    # TODO: query will set up the filter bar
    # and widget states.
    if query?
      query = JSON.parse(query)

    Application.pages.close(false)
    if name?
      Application.tabs?.loadTabByName(name, query)
    else
      Application.tabs?.loadDefaultTab()

  page:(name) =>
    if name?
      Application.pages?.loadPageByName(name)
    else
      Application.tabs?.loadDefaultTab()
    