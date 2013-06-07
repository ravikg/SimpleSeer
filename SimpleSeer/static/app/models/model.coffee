module.exports = class Model extends Backbone.Model
  cachebust: true

  #this will be overloaded by appropriate plugins
  getPlugin: (name) ->
    return

  getPluginMethod: (name, fn) =>
    p = @getPlugin(name)
    unless p?
      return

    unless p[fn]?
      return

    p[fn]

  url:=>
    url = super()
    if @cachebust
      url += "?cachebust="+new moment().valueOf()
    return url

