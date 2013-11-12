module.exports = class Model extends Backbone.Model

  initialize: =>
    @cachebust = true

  url: =>
    url = super()
    if @cachebust
      url += "?cb="+new moment().valueOf()
    return url
