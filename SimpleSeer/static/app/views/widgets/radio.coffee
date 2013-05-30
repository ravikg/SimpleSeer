SubView = require 'views/core/subview'
template = require './templates/radio'
application = require 'application'

module.exports = class radio extends SubView
  template:template
  defaultValue:null
  radios:undefined

  initialize: =>
    super()
    if @options.radios?
      @radios = @options.radios

  getRenderData: =>
    radios:@radios

  afterRender: =>
    $('.radio').buttonset()