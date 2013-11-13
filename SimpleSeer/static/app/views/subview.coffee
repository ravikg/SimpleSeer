[ View ] = [ require('views/view') ]

module.exports = class SubView extends View

  initialize:(options) =>
    super(options)

  render: =>
    if @rendered then return @
    tagName = @tagName || 'div'
    className = @className || ''
    
    if @options.append
      parent = @options.parent.$
      if !parent('#'+@options.append).length
        $(@options.selector).append('<#{tagName} class="#{className}" id="#{@options.append}"/>')
      @setElement( parent('#'+@options.append) )
    else
      el = $( @options.selector )
      @setElement( el )
      el.addClass( className )

    if @.constructor?
      # Add the 'data-widget="Constructor"'
      # property for ease of stylesheets.
      ctor = String(@.constructor)
      ptn = ctor.match(/function (.*)\(\)/)
      if ptn[1]? then @$el.attr("data-widget", ptn[1])          

    super()
    return @