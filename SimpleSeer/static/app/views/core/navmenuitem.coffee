SubView = require '../subview'
application = require '../../application'
template = require './templates/navmenuitem'

module.exports = class navMenuItem extends SubView
  template:template
    
  initialize: =>
    @navLinks = {}
    
  render: =>
    super()
    #ul = @$el.find(".navLinks")

    for i,o of @navLinks
      ul = @getLinkGroup o.linkGroup
      ul.append('<li><a href="'+i+'" class="tab">'+(o.title || '')+'</a></li>')
    return @

  addNavigation: (href, obj) =>
    @navLinks[href] = obj

  getLinkGroup: (linkGroup) =>
    if !linkGroup?
      ul = @$el.find('[linkgroup="default"]')
    else
      ul = @$el.find('[linkgroup="'+linkGroup+'"]')
    if ul.length == 0
      @$el.prepend('<ul class="navLinks" linkgroup="'+linkGroup+'"></ul>')
      ul = @$el.find('[linkgroup="'+linkGroup+'"]')
      ul.append('<li>'+linkGroup+'</li>')
    return ul
