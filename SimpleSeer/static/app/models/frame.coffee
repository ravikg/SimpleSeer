[ Model ] = [ require("models/model") ]

module.exports = class Frame extends Model
  urlRoot: "/api/frame"

  parse:(response) =>
    features = response.features
    response.features = {}
    if features and features.length
      for f in features
        name = f.featuretype.toLowerCase()
        Plugin = require("plugins/feature/#{name}")
        if !response.features[name]
          response.features[name] = []
        response.features[name].push(new Plugin(f))
    delete response.thumbnail_file
    delete response.imgfile
    return response

  save:(attributes, options) =>
    if @attributes.features? then delete @attributes.features
    if @attributes.results? then delete @attributes.results
    super(attributes, options)