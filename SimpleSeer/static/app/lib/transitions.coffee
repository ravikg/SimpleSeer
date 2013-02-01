do ($ = jQuery) ->
  $.effects.throbber = (o) ->
    done = o.callback || =>
    modes = ['show','hide']
    # Create element
    el = $(@)
    mode = $.effects.setMode( el, o.options.mode || "toggle" )
    if mode == 'hide'
      if !o.color?
        o.color = '#FFF'
      if !o.opacity?
        o.opacity = 0.8
      if !o.graphic?
        o.graphic = '/img/loading.gif'
      t = $('<div class="throbber transistion">')
        .width(el.width())
        .height(el.height())
        .css({'background-color':o.color,opacity:o.opacity})
        .html('<img style="vertical-align:middle" src="'+o.graphic+'">')
        .hide()
      el.prepend(t)
    else
      t = el.find('.throbber.transistion')
      _done = done
      done = ->
        t.remove()
        _done()
    t.animate
      opacity: if mode is 'show' then 'hide' else 'show'
    ,
      queue: false
      duration: o.duration
      easing: o.easing
      complete: done
