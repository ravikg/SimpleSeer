[ View ] = [ require('views/view') ]

module.exports = class SubView extends View

  initialize:(options) =>
    super(options)

  render: =>
    tagName = @tagName or "div"
    className = @className or ""
    
    if @options.append
      # Append the subview to the container
      # at @options.append.
      parentEl = @options.parent.$el
      container = parentEl.find(@options.append)
      if container.length
        el = $("<#{tagName}/>").addClass(className)
        container.append( el )
        @setElement( el )
    else
      # Turn the container at @options.selector
      # into the subview.
      el = $( @options.selector )
      el.addClass( className )
      @setElement( el )
      

    if @.constructor?
      # Add the 'data-widget="Constructor"'
      # property for ease of stylesheets.
      ctor = String(@.constructor)
      ptn = ctor.match(/function (.*)\(\)/)
      if ptn[1]? then @$el.attr("data-widget", ptn[1])          

    super()
    return @