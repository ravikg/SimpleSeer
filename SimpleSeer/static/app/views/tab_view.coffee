SubView = require './subview'
application = require '../application'

module.exports = class Tab extends SubView
  selected:false
  
  initialize: () =>
    ul = @options.parent.$el.find('ul')
    ul.append('<li><a href="#'+@options.append+'" class="tab">'+(@title || '')+'</a></li>')
        
    if !@options.parent.$('#'+@options.append).length
      @options.parent.$(@options.selector).append('<div id="'+@options.append+'" class="tab" />')
    super()
    
  select: =>
    @selected = true
    @render()
    #console.log @options.parent.$el.tabs
    
  unselect: =>
    @selected = false
    #@$el.remove()
