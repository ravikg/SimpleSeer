SubView = require '../subview'
application = require '../../application'
template = require './templates/navmenuitem'

module.exports = class navMenuItem extends SubView
  template:template
  
  initialize: =>
    @navLinks = {}
    
  render: =>
    super()
    ul = @$el.find(".navLinks")
    for i,o of @navLinks
      ul.append('<li><a href="'+i+'" class="tab">'+(o.title || '')+'</a></li>')
    return @

  addNavigation: (href, obj) =>
    @navLinks[href] = obj
