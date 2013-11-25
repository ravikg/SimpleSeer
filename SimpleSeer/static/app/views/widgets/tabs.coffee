[View, Template, Collection] = [
  require("views/view"),
  require("./templates/tabs"),
  require("collections/tabs")
]

module.exports = class Tabs extends View
  template: Template

  events: =>
    {"click .tab": "clickEvent"}

  initialize: =>
    super()
    @decayTimeouts = {}
    @collection = new Collection()
    @collection.fetch({async: false})
    @render()

  getRenderData: =>
    tabs = @collection.models[0].get("tabs")
    return {tabs: tabs}

  afterRender: =>
    refl = _.throttle(@reflow, 300)
    $(window).unbind("resize").bind("resize", refl)

  _tabWhere:(query) =>
    models = @collection.models[0].get("tabs")
    return _.findWhere(models, query)

  clickEvent:(e) =>
    id = $(e.currentTarget).data("id")
    tab = @_tabWhere({"model_id": id})
    @setTab(tab)

  removeAndDecay: =>
    id = $(".tab.active").data("id")
    tab = @_tabWhere({"model_id": id})
    @subviews["tab-#{id}"]?.unselect()
    if tab.decay?
      fn = => @decay(id)
      timeout = setTimeout(fn, tab.decay)
      @decayTimeouts[id] = timeout
    @$(".tab.active, .content .area").removeClass("active")

  decay:(id) =>
    if @subviews["tab-#{id}"]?
      @subviews["tab-#{id}"].remove()
      delete @subviews["tab-#{id}"]
      selector = ".area[data-id=#{id}]"
      @$(selector).append($("<div/>"))

  setTab:(tab, query) =>
    @removeAndDecay()
  
    name = @_sanitizeName(tab.name)
    id = tab.model_id
    view = tab.view

    if query?
      Application.router.navigate("tab/#{name}/#{ JSON.stringify(query) }")
    else 
      Application.router.navigate("tab/#{name}/{}")
      Application.router.clearParams()

    if !@subviews["tab-#{id}"]?
      # Create the subview
      file = require("views/#{view}")
      selector = ".area[data-id=#{id}] div"
      sv = @addSubview("tab-#{id}", file, @$(selector))
      sv.render()
    else
      # Locate the subivew
      sv = @subviews["tab-#{id}"]

    if @decayTimeouts[id]?
      clearTimeout(@decayTimeouts[id])

    @$(".tab[data-id=#{id}]").addClass("active")    
    @$(".content .area[data-id=#{id}]").addClass("active")
    sv.select(query || Application.router.query)  

  getActiveSubview: =>
    id = @$(".tab.active").data("id")
    if @subviews["tab-#{id}"]?
      return @subviews["tab-#{id}"]
    return

  loadTabByName:(name, query) =>
    for model in @collection.models[0].get("tabs")
      if @_sanitizeName(model.name) == @_sanitizeName(name)
        return @setTab(model, query)
    console.error "Couldn't select tab '#{name}'"

  loadDefaultTab: =>
    tab = @_tabWhere({"selected": true})
    @setTab(tab)

  _sanitizeName:(name) =>
    name = name.replace(/\s/g, "-")
    name = name.toLowerCase()
    return name