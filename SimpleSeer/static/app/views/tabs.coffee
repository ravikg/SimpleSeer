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
    @collection = new Collection()
    @collection.fetch({async: false})
    @render()

  getRenderData: =>
    tabs = @collection.models[0].get("tabs")
    return {tabs: tabs}

  _tabWhere:(query, singleton=true) =>
    models = @collection.models[0].get("tabs")
    if singleton
      return _.findWhere(models, query)
    else
      return _.where(models, query)

  clickEvent:(e) =>
    id = $(e.currentTarget).data("id")
    tab = @_tabWhere({"model_id": id})
    @setTab(tab)

  setTab:(tab) =>
    @$(".tab.active").removeClass("active")
    @$(".tab[data-id=#{tab.model_id}]").addClass("active")
    @$(".content .area").hide()

    Application.router.navigate("tab/#{@_sanitizeName(tab.name)}")

    if !@subviews["tab-#{tab.model_id}"]?
      try
        file = require("views/#{tab.view}")
        selector = ".area[data-id=#{tab.model_id}]"
        sv = @addSubview("tab-#{tab.model_id}", file, @$(selector))
        sv.render()
      catch error
        console.error("Couldn't load 'views/#{tab.view}'")
    @$(".content .area[data-id=#{tab.model_id}]").show()

  loadTabByName:(name) =>
    tab = null
    # Search for tab in models
    for model in @collection.models[0].get("tabs")
      if @_sanitizeName(model.name) == @_sanitizeName(name)
        @setTab(model)
        return
    console.error "Couldn't select tab '#{name}'"

  loadDefaultTab: =>
    tab = @_tabWhere({"selected": true})
    @setTab(tab)

  _sanitizeName:(name) =>
    name = name.replace(/\s/g, "-")
    name = name.toLowerCase()
    return name