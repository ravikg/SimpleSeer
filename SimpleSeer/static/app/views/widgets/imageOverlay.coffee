SubView = require 'views/core/subview'
template = require './templates/imageOverlay'
application = require 'application'

module.exports = class imageOverlay extends SubView
  className:"imageOverlay"
  tagName:"div"
  template: template  
