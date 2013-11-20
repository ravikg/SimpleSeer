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

  setTab:(tab, query) =>
    @$(".tab.active").removeClass("active")
    @$(".tab[data-id=#{tab.model_id}]").addClass("active")
    @$(".content .area").removeClass("active")

    name = @_sanitizeName(tab.name)

    if query?
      params = JSON.stringify(query)
      Application.router.navigate("tab/#{name}/#{params}")
    else 
      Application.router.navigate("tab/#{name}")

    if !@subviews["tab-#{tab.model_id}"]?
      file = require("views/#{tab.view}")
      selector = ".area[data-id=#{tab.model_id}] div"
      sv = @addSubview("tab-#{tab.model_id}", file, @$(selector))
      sv.render()
    else
      sv = @subviews["tab-#{tab.model_id}"]
    
    sv.select(query)  
    @$(".content .area[data-id=#{tab.model_id}]").addClass("active")

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