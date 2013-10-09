Model = require "./model"
application = require "application"

module.exports = class Frame extends Model
  urlRoot: "/api/frame"

  parse: (response) =>
    features = response.features
    response.features = {}
    if features and features.length
      for f in features
        name = f.featuretype.toLowerCase()
        try
          plugin = require "plugins/feature/"+name
          if !response.features[name]
            response.features[name] = []
          response.features[name].push(new plugin(f))
        catch e
          if application.debug
            console.info "Error loading javascript plugin feature #{name}:"
            console.error e
    delete response.thumbnail_file
    delete response.imgfile
    ###
    if not response.thumbnail_file? or not response.thumbnail_file
      response.thumbnail_file = "/grid/thumbnail_file/" + response.id
    ###
    return response

  save:(attributes, options)=>
    if @attributes.features?
      delete @attributes.features
    if @attributes.results?
      delete @attributes.results

    super(attributes, options)