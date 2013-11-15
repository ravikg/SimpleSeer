[ Model ] = [ require("models/model") ]

module.exports = class Dashboard extends Model
  urlRoot: "/api/dashboard"
  loaded: false

  initialize: =>
    if @attributes.view
      @view = @attributes.view
      delete @attributes.view
    super()