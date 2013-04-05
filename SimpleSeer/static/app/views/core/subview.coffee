#### subviews.coffee extends view.coffee and is used to attach child views inside of a parent view
# - - -
View = require 'views/core/view'

module.exports = class SubView extends View

  initialize: =>
    @htmltags = {}
    super()

  # Overrides render in `view.coffee`
  render: () =>
    if @rendered
      return @
    tagName = @tagName || 'div'
    className = @className || ''
    tags = ''
    # Use `@htmltags` to pass key-pair values in as tags  
    # ie:  `{style:'width:100%;'}` becomes `style="width:100%;"`
    for i,o of @htmltags
      tags+= i+'="'+o+'" '
    # Use `append` when creating a subview to append subview to an html element
    if @options.append
      if !@options.parent.$('#'+@options.append).length
        $(@options.selector).append('<'+tagName+' class="'+className+'" id="'+@options.append+'" '+tags+'/>')
      @setElement @options.parent.$ '#'+@options.append
    else
      foo = @setElement $ @options.selector
    super
    @

  # Used for pagination
  _pageTrigger: =>
    @trigger 'page'
    for i,o of @subviews
      if !o.onPage?
        o._pageTrigger()
    return

  _scrollTrigger: =>
    @trigger 'scroll'
    for i,o of @subviews
      if !o.onScroll?
        o._scrollTrigger()
    return