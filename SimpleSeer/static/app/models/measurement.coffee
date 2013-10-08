Model = require "./model"
Application = require "application"

module.exports = class Measurement extends Model
  urlRoot: -> "/api/measurement"

  parse: (response) =>
    if response.tolerance_list
      for i,o of response.tolerance_list
        tolerance = undefined
        tolerance = Application.tolerance_list.get(id=o.id)
        if tolerance
          response.tolerance_list[i] = tolerance
    return response

  save: (attributes, options) =>
    super(attributes, options)