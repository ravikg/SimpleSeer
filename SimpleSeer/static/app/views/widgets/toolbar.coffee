[View, Template] = [
  require("views/view"),
  require("./templates/toolbar")
]

module.exports = class Toolbar extends View
  template: Template

  initialize: =>
    super()
    @items = 0

  events: =>
    "click [data-widget=MenuItem]": "clickEvent"

  clickEvent:(e) =>
    # Find the subview based on
    # the event target.
    for i, sv of @subviews
      if sv.el is e.currentTarget
        sv.onClick?()

  getRenderData: =>
    client: Application.settings.ui_pagename

  addItem:(view, options) =>
    name = "menuitem-#{@items++}"
    options = _.extend(options, { append: @$(".right") })
    sv = @addSubview(name, require(view), null, options)
    sv.render()

  afterRender: =>
    def = "views/widgets/menuitem"
    @addItem(def, {title: "", icon: "/img/seer/Header_Image_Settings.svg"})
    @addItem(def, {title: "Login", icon: "/img/seer/Header_Image_User.svg"})
