SubView = require 'views/core/subview'
template = require './templates/textfield'
application = require 'application'

module.exports = class textfield extends SubView
  template:template
  text:undefined
  
  getRenderData:=>
    text:@text