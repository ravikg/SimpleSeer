module.exports = class Router extends Backbone.Router

  initialize: =>
    @query = {params: {}, filters: []}

  validateQuery: =>
    if !@query.params?
      @query.params = {}
    if !@query.filters?
      @query.filters = []

  routes: =>
    "": "tab"
    "tab/:name(/)*query": "tab"
    "page/:name": "page"

  tab:(name, query="{}") =>
    @query = JSON.parse(query)
    @validateQuery()

    Application.pages.close(false)
    if name?
      Application.tabs?.loadTabByName(name, @query)
    else
      Application.tabs?.loadDefaultTab()

  page:(name) =>
    if name?
      Application.pages?.loadPageByName(name)
    else
      Application.tabs?.loadDefaultTab()

  setFilters:(filters) =>
    @query.filters = filters
    @updateURLWithQuery(false)

  getFilters: =>
    return @query.filters
    
  setParam:(key, value, trigger) =>
    @query.params[key] = value
    @updateURLWithQuery(trigger)

  getParam:(key) =>
    return @query.params[key]

  removeParam:(key) =>
    delete @query.params[key]

  clearParams:(trigger) =>
    @query.params = {}
    @updateURLWithQuery(trigger)

  updateURLWithQuery:(trigger=false) =>
    hash = document.location.hash
    regex = /(\#[a-zA-Z0-9\-]+\/[a-zA-Z0-9\-]+\/)\{/
    partial = hash.match(regex)?[1]
    stfy = JSON.stringify(@query)
    if partial?
      Application.router.navigate("#{partial}#{stfy}", {trigger: trigger})
    else
      Application.router.navigate("#{hash}/#{stfy}", {trigger: trigger})    