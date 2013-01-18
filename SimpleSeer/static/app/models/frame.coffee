Model = require "./model"
application = require "application"

module.exports = class Frame extends Model
  urlRoot: "/api/frame"

  parse: (response) =>
    response.features = {}
    if response.results and response.results.length
      for r in response.results
        try
          plugin = require "plugins/feature/"+r.inspection_name.toLowerCase()
          if !response.features[r.inspection_name]?
            response.features[r.inspection_name] = new plugin()
          response.features[r.inspection_name].addTrait(r)
        catch e
          if application.debug
            console.info "Error loading javascript plugin feature:"
            console.error e

    if not response.thumbnail_file? or not response.thumbnail_file
      response.thumbnail_file = "/grid/thumbnail_file/" + response.id
    return response