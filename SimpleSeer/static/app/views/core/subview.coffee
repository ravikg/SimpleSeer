#### subviews.coffee extends view.coffee and is used to attach child views inside of a parent view
# - - -
View = require 'views/core/view'

module.exports = class SubView extends View

  initialize: =>
    super()
    @htmltags = {}
    
  # Overrides render in `view.coffee`
  render: () =>
    if @rendered
      return @
    tagName = @tagName || 'div'
    className = @className || ''
    # Use `append` when creating a subview to append subview to an html element
    if @options.append
      # Use `@htmltags` to pass key-pair values in as tags
      # ie:  `{style:'width:100%;'}` becomes `style="width:100%;"`
      tags = ''
      for i,o of @htmltags
        tags+= i+'="'+o+'" '
      if !@options.parent.$('#'+@options.append).length
        $(@options.selector).append('<'+tagName+' class="'+className+'" id="'+@options.append+'" '+tags+'/>')
      @setElement @options.parent.$ '#'+@options.append
    else
      el = $ @options.selector
      foo = @setElement el
      el.addClass className
      # Use `@htmltags` to pass key-pair values in as tags
      # ie:  `{style:'width:100%;'}` becomes `style="width:100%;"`
      for i,o of @htmltags
        el.attr i,o
    super
    @

  select: =>
    if @filtercollection?
      @filtercollection.fetch({filtered:true})

  # Used for pagination
  _pageTrigger: =>
    @trigger 'page'
    for i,o of @subviews
      if !o.onPage?
        o._pageTrigger()
    return

  _scrollTrigger: (per) =>
    @trigger 'scroll', per
    for i,o of @subviews
      if !o.onScroll?
        o._scrollTrigger(per)
    return
