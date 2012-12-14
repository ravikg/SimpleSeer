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
      li = $('<li></li>')
      li.append('<a href="'+i+'" class="tab">'+(o.title || '')+'</a>')
      li.append('<div class="icon" style="background-image: url()"></div>')
      ul.append(li)
    return @

  addNavigation: (href, obj) =>
    @navLinks[href] = obj

  getLinkGroup: (linkGroup) =>
    if !linkGroup?
      ul = @$el.find('[linkgroup="default"]')
    else
      ul = @$el.find('[linkgroup="'+linkGroup+'"]')
    if ul.length == 0
      @$el.append('<ul class="navLinks" linkgroup="'+linkGroup+'"></ul>')
      ul = @$el.find('[linkgroup="'+linkGroup+'"]')
      @$el.find(".navGroups").append('<option>'+linkGroup+'</option>')
    return ul
