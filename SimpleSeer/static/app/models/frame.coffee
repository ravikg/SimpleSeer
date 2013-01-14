Model = require "./model"

module.exports = class Frame extends Model
  urlRoot: "/api/frame"

  parse: (response) =>
    #if response.features  and response.features.length
    #  console.dir response.features
    #  console.dir response.results
    #  halt()
    response.features = {}
    if response.results and response.results.length
      for r in response.results
        plugin = require "plugins/"+r.inspection_name
        if !response.features[r.inspection_name]?
          # todo: put a try catch here
          response.features[r.inspection_name] = new plugin()
        response.features[r.inspection_name].addTrait(r)
      #if response.featires[]
      #  response.features = new Feature(response.results)
    #  #response.features = new FeatureSet( (new Feature(f) for f in response.results) )
    #response.features = {}
    if not response.thumbnail_file? or not response.thumbnail_file
      response.thumbnail_file = "/grid/thumbnail_file/" + response.id
    return response