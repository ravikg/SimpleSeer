SubView = require 'views/core/subview'
template = require './templates/radio'
application = require 'application'

module.exports = class radio extends SubView
  template:template
  defaultValue:null
  radios:undefined

  events: =>
    "change input": "update"

  initialize: =>
    super()
    if @options.radios?
      @radios = @options.radios

  getRenderData: =>
    radios:@radios

  afterRender: =>
    @$('.radio').buttonset()

  update: =>
    value = @$("input:checked").attr("value")
    @trigger("update", @radios[0].id, value)

  setValue:(value) =>
    @$(".radio input:checked").removeAttr("checked")
    @$(".radio ##{value}").attr("checked", "checked")
    @$('.radio').buttonset("refresh")

