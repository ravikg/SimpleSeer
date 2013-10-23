Model = require "./model"
Application = require "application"

module.exports = class Measurement extends Model
  urlRoot: -> "/api/measurement"

  save: (attributes, options) =>
    super(attributes, options)