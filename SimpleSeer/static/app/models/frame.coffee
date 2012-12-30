Model = require "./model"
Feature = require "models/feature"
#FeatureSet = require "../collections/featureset"


module.exports = class Frame extends Model
  urlRoot: "/api/frame"

  parse: (response) =>
    #if response.features  and response.features.length
    #  console.log response
    #  halt()
    #if response.results and response.results.length
    #  for f in response.results
    #    feat = new Feature(f)
    #    response.features.push feat
    #  #response.features = new FeatureSet( (new Feature(f) for f in response.results) )
    response.features = {}
    if not response.thumbnail_file? or not response.thumbnail_file
      response.thumbnail_file = "/grid/thumbnail_file/" + response.id
    return response