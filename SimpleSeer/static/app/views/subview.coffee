require 'lib/view_helper'
View = require './view'

module.exports = class SubView extends View
  options:
    parent: null
    selector: null
  htmltags: {}

  render: () =>
    if @rendered
      return @
    tagName = @tagName || 'div'
    className = @className || ''
    tags = ''
    for i,o of @htmltags
      tags+= i+'="'+o+'" '
    if @options.append
      if !@options.parent.$('#'+@options.append).length
        @options.parent.$(@options.selector).append('<'+tagName+' class="'+className+'" id="'+@options.append+'" '+tags+'/>')
      @setElement @options.parent.$ '#'+@options.append
    else
      foo = @setElement @options.parent.$ @options.selector
      #foo.$el.addClass className
    super
    @
    
