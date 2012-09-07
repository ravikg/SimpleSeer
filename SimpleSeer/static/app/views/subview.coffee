require 'lib/view_helper'
View = require './view'

module.exports = class SubView extends View
  options:
    parent: null
    selector: null
  htmltags: {}

  render: () =>
    if @options.append
      if !@options.parent.$('#'+@options.append).length
        tagName = @tagName || 'div'
        className = @className || ''
        tags = ''
        for i,o of @htmltags
          tags+= i+'="'+o+'" '
        @options.parent.$(@options.selector).append('<'+tagName+' class="'+className+'" id="'+@options.append+'" '+tags+'/>')
      @setElement @options.parent.$ '#'+@options.append
    else
      @setElement @options.parent.$ @options.selector
    super
    @
