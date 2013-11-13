[Application, 
 SubView,
 Collection,
 TableTemplate,
 RowTemplate] = [
  require('application'),
  require('views/core/subview'),
  require('collections/table'),
  require('./templates/table'),
  require('./templates/table_row')
]

module.exports = class Table extends SubView
    

  ''' INIT '''

  initialize: =>
    super()

    # Table.coffee v2.0
    #
    # ===========================
    #
    # size: (full), widget
    # pagination: noscroll, (infinite), num
    # header: fixed, (float)
    # settings: true, (false)
    # collection: 'collections/table', ''
    # model: ('models/frame'), ''
    # url: ('api/frame'), ''
    # sortable: (true), false
    # sorttype: (db), js
    # editable: true, (false)

    # Build everything
    @settings = @_settings() # Static settings
    @variables = @_variables() # Class level variables
    @template = @variables.template # Set main template
    @collection = @_collection() # Define data collection

    if @settings.pagination is 'infinite' # Set pagination type
      @on 'page', @_infinite
    if @settings.header is 'float' # Set header style
      @on 'scroll', @_scroll

    # Init table
    @collection.fetch() # We are ready to render that table!

  # Build a settings object from our configuration file
  _settings: =>
    settings = {}
    settings.classes = ['table', 'zebra']
    settings.styles = []
    settings.toggles = @options.toggles ? false
    settings.hideEmpty = @options.hideEmpty ? false
    settings.size = @options.size ? 'full'
    if settings.size is 'full'
      settings.classes.push('border')
    settings.classes.push(settings.size)
    settings.pagination = @options.pagination ? 'infinite'
    settings.classes.push(settings.pagination)
    settings.clearOnFetch = (if settings.pagination is 'infinite' then true else true)
    settings.header = @options.header ? 'float'
    settings.classes.push(settings.header)
    settings.settings = @options.settings ? false
    if @options.data?
      settings.collection = @options.data.collection ? 'collections/table'
      settings.collection = require settings.collection
      settings.model = @options.data.model ? 'models/frame'
      settings.model = require settings.model
      settings.url = @options.data.url ? 'api/frame'
      settings.viewid = @options.data.viewid ? '5089a6d31d41c855e4628fb0'
      settings.limit = @options.data.limit ? 100
    settings.subscribe = @options.subscribe ? []
    settings.columns = @options.columns ? []
    settings.sortable = @options.sortable ? true
    settings.sorttype = @options.sorttype ? 'db'
    defaultSort = settings.sortable ? false
    for o,i in settings.columns
      o.sortable = o.sortable ? defaultSort
      o.visible = o.visible ? true
    return settings

  # Append addition variables to our class scope
  _variables: =>
    variables = {}
    variables.template = TableTemplate
    variables.rowTemplate = RowTemplate
    variables.preHTML = ""
    variables.postHTML = ""
    variables.data = []
    variables.cleardata = false
    variables.rows = []
    variables.showHidden = (if @settings.hideEmpty then false else true)
    variables.clearrows = false
    variables.sortkey = undefined
    variables.sortdirection = -1
    variables.limit = @settings.limit
    variables.skip = 0
    variables.nodata = false
    variables.hidden = {}
    variables.emptytoggle = false
    variables.scrollElem = '#content #slides'
    variables.left = null
    variables.navigateId = 0
    variables.page = 1
    variables.init = 0
    if @settings.header is 'float'
      variables.preHTML += '<div class="header">
              <div class="float">
                <table class="table floater borderTop"></table>
              </div>
            </div>'

    return variables



  ''' GETTING / SETTING DATA '''

  # Build the collection and return it
  _collection: (args={}) =>
    if args and args.bindFilter?
      bindFilter = args.bindFilter
    else if @options.parent.dashboard? and @options.parent.dashboard.options.parent.options.context
      bindFilter = Application.context[@options.parent.dashboard.options.parent.options.context].filtercollection
    else if @options.parent.dashboard? and Application.context[@options.parent.dashboard.options.context]?.filtercollection?
      bindFilter = Application.context[@options.parent.dashboard.options.context].filtercollection
    collection = new @settings.collection([], {
      bindFilter: bindFilter, 
      model: @settings.model, 
      viewid: @settings.viewid
    })

    collection.setParam 'limit', @variables.limit
    collection.setParam 'skip', @variables.skip

    collection.on('reset', @_data)

    return collection


  #subscribe:(channel='Chart/'+@model.attributes.name+'/') =>
  #  if @model.attributes.realtime && Application.socket
  #    Application.socket.on 'message:'+channel, @_newData
  #    if !Application.subscriptions[channel]
  #      Application.socket.removeListener "message:#channel", @_newData
  #      Application.subscriptions[channel] = Application.socket.emit 'subscribe', channel



  # Safe function to update the collection with passed params
  # @TODO: Pass set/unset key to params
  # If @collection does not exist, it runs @_collection to build initial collection.
  _update: (collection, params, filtered = false, async = true) =>
    if collection
      for i,o of params
        collection.setParam i, o

      collection.fetch({async: async, filtered:filtered})
      return collection

  # Wrapper function to clear rendered rows, or rows stored in our data variable
  _clear: =>
    if @variables.cleardata
      @variables.data = []
      @variables.cleardata = false
    if @variables.clearrows
      @variables.rows = []
      @variables.clearrows = false


  ''' RENDERING '''

  # Main data render trigger function
  _data: (a = null, b = null) =>
    if typeof(a) == 'object'
      @variables.cleardata = true
      @variables.clearrows = true

    if @collection.getParam?
      if @collection.getParam('skip') is 0
        @variables.cleardata = true
        @variables.skip = 0

    if @settings.sorttype is 'db'
      if !b # Let db handle what should and shouldn't be available.
        @variables.clearrows = true

    @_clear()

    data = []
    if !@collection or @collection.length <= 1
      if @collection.models and @collection.models[0]
        @variables.nodata = false
      else
        @variables.nodata = true
    else
      @variables.nodata = false

    if @variables.newrows and @variables.newrows.length >= 1
      @variables.nodata = false

    if !@variables.nodata
      data = @_formatData @collection.models
      if data
        @variables.data = @variables.data.concat(data)

        if !@variables.init and @settings.sorttype == 'js'
          @variables.init = 1
          @variables.sortdirection = 1
          @$(".table th.sortable:first").click()
          return

        if @settings.pagination == "num"
          if @variables.navigateId
            page = Math.floor(@variables.navigateId / @settings.limit)
            mod = @variables.navigateId % @settings.limit
            if mod
                page++
            if page == 1
              @variables.skip = 0
            else
              @variables.skip = page * @settings.limit - @settings.limit
          for o,i in @variables.data
            if i >= @variables.skip and i < @settings.limit + @variables.skip
              if @variables.direction is 1
                @variables.rows.unshift(@_row(o))
              else
                @variables.rows.push(@_row(o))
        else
          for o,i in @variables.data
            if @variables.direction is 1
              @variables.rows.unshift(@_row(o))
            else
              @variables.rows.push(@_row(o))
        @render()
    else
      @variables.data = []
      @variables.rows = []
      @$el.find('.table.static tbody').html('<tr><td class="nodata" colspan="' + @settings.columns.length + '">No data within filter parameters</td></tr>')

  # Generally overwrite in client repo to format data for rendering
  # Takes in a collection of data returns that same collection
  # But with a new field in attributes called "formatted" which
  # is an object with {value:value, classes:classes}
  _formatData: (data) =>
    for o,i in data
      for y,x in @settings.columns
        if y.data?.key
          location = y.data.key.split('.')

          if !o.attributes.formatted
            o.attributes.formatted = {}
          if !o.attributes.formatted[y.data.key]
            o.attributes.formatted[y.data.key] = {value:'', classes:[]}

          if location[0] is 'capturetime_epoch'
            o.attributes.formatted[y.data.key].value = moment(o.get(location[0])).format('YYYY-MM-DD H:mm')
          
          if y.href
            href = y.href
            pattern = /\#\{([\w\.\_]+)\}/g
            for placeholder in y.href.match(pattern)
              path = placeholder.slice(2, -1)
              if path is "this"
                val = o.get(location[0])
                if val instanceof Array and val[0]? # We have a group by in the list
                  val = val[0]
                if location[1]
                  val = val[location[1]]
              else
                val = o.get(path)
              href = href.replace(placeholder, val)
            o.attributes.formatted[y.data.key].href = href

    return data

  # Takes row data, returns row html
  _row: (row = {}) =>
    return @variables.rowTemplate @_formatRow(row)

  # Takes row data, returns formatted row data, cell content
  _formatRow: (row) =>
    id = row.get('id') ? ''
    values = []

    for o,i in @settings.columns
      if o.visible
        t = row.get('formatted')[o.data.key] ? ''
        values.push @_formatCell o, t
    return {id: id, values: values}

  # Takes cell data, returns formatted cell content/html
  _formatCell: (settings, value) =>
    cell = {title:'', html:'', data:[]}
    
    for i,o of settings.data
      cell.data.push('data-'+i+'="'+o+'"')
    
    cell.raw = value.value
    cell.html = value.value
    cell.classes = value.classes

    if settings.href
      cell.href = value.href

    return cell

  _pages: =>
    if @settings.pagination == "num"
      arr = [1]
      if @variables.data and @variables.data.length > 0
        total = @variables.data.length
        limit = @settings.limit
        floor = Math.floor(@variables.data.length / @settings.limit)
        mod = @variables.data.length % @settings.limit
        if total > limit
          if floor
            if mod
              floor++
            i = 2
            while i <= floor
              arr.push(i)
              i++
    else
      arr = []
    return arr

  # Pass data to handlebars to render
  getRenderData: =>
    page: @variables.page
    pages: @_pages()
    toggles: @settings.toggles
    classes: @settings.classes
    styles: @settings.styles
    header: @variables.preHTML
    footer: @variables.postHTML
    columns: @settings.columns
    rows: @variables.rows
    pageButtons: @options.page == "page"

  # Clean up stuff after we render
  afterRender: =>
    dir = (if @variables.sortdirection is -1 then "asc" else "desc")
    @$el.find(".th[data-key=\"#{@variables.sortkey}\"]")
      .removeClass("sort-asc sort-desc")
      .addClass("sort-#{dir}")

    if @settings.header is 'float'
      @_header()
      if !@variables.scroll
        @variables.scroll = $(@variables.scrollElem)
      @variables.left = 0
      @_scrollLeft()

    if @settings.hideEmpty
      if @variables.emptytoggle
        @$el.find('.static tbody').prepend('<tr><td class="td showhidden" colspan="' + @settings.columns.length + '"><button class="button">Show hidden rows?</button></td></tr>')
        
    page = @variables.page
    if @variables.navigateId
      page = Math.floor(@variables.navigateId / @settings.limit) + 1
      @variables.navigateId = 0
    $(".pagination .item[data-page='#{page}'").addClass('selected')

    if @variables.highlight
      highlight = @variables.highlight
      $("tr[data-part='#{highlight}']").addClass("highlighted")
      if $("tr[data-part='#{highlight}']").length > 0
        $("#content #slides").scrollTop($("tr[data-part='#{highlight}']").offset().top - 150)
      $("tr[data-part='#{highlight}'] td:nth-child(2) input:first-child'").focus()

  # Used to initilize or update floating header
  _header: () =>
    @$(".table.floater").html('')
    @$(".table.static .thead").clone().appendTo('.table.floater').css('opacity', 1)

    table = @$('.table.static')
    header = @$('.header')
    static = @$('.table.static .thead')
    floater = @$('.table.floater .thead')

    header.width(static.width() + 1)

    lastkey = ""
    _.each static.find('.th'), (column) =>
      key = $(column).data('key')
      placeholder = $($(column).find('.placeholder'))
      width = placeholder.width() + parseInt(placeholder.css('padding-left'), 10) + parseInt(placeholder.css('padding-right'), 10)
      width += 1
      if $(column).is(":visible")
        lastkey = key
      floater.find(".th[data-key=\"#{key}\"]").css('width', width).css('height', $(column).height() - 2)

    if lastkey
      last = floater.find(".th[data-key=\"#{lastkey}\"]")
      last.css('width', last.width() - 1)

  select: =>
    if @settings.size is 'full'
      $("#slides").addClass "nopad"

  unselect: =>
    if @settings.size is 'full'
      $("#slides").removeClass "nopad"



  ''' EVENT HANDLING '''

  events: =>
    "click th.sortable":"_sort" # Click to sort
    "click .pagination .item":"_page" # Click to page
    "click .downloads button":"_download" # Click to download
    "click .toggles":"_toggles" # Toggle toggles menu
    "click .toggle":"_toggle" # Toggle toggle
    "click .showhidden .button":"_showHidden"

  _showHidden: (e) =>
    @variables.showHidden = true
    @variables.emptytoggle = false
    @collection.resetParam 'query'
    @_update(@collection, {}, false, true)

  _empty: =>
    if @emptyCollection.length > 0
      @variables.emptytoggle = true
    else
      @variables.emptytoggle = false

  _sort: (e, trigger = null) =>
    direction = @variables.sortdirection
    kind = (if e.currentTarget then 'event' else 'filter')
    if kind is 'event'
      key = $(e.currentTarget).data('key')
      if direction is 1
        @variables.sortdirection = -1
      else
        @variables.sortdirection = 1
    else if kind is 'filter'
      if direction = 1
        direction = -1
      else
        direction = 1
      key = $(e).data('key')

    if key != @variables.sortkey
      if @settings.hideEmpty
        @variables.showHidden = false

    @variables.sortkey = key

    if @settings.sorttype is 'db' # Let the backend do the sorting
      type = $(e.currentTarget).data('type')
      if type is 'measurement'
        @collection.setParam 'sorttype', 'measurement'
      else
        @collection.resetParam 'sorttype'
      @variables.clearrows = true
      @variables.cleardata = true

      if @settings.hideEmpty # Check to see if we even care about hiding empty rows
        query = @collection.getParam 'query'
        if !@variables.showHidden # We need to check if there is rows to hide
          @emptyCollection = @_collection()
          @emptyCollection.on('reset', @_empty)

          if query and query.criteria
              _.each query.criteria, (criteria, id) =>
                if criteria.isset
                  delete(query.criteria[id])
              query.criteria.push({"type":"frame","isset":1,"name":key})
              query.criteria = _.compact(query.criteria)
          else
            query = {"logic":"and","criteria":[{"type":"frame","isset":1,"name":key}]}
          
          cquery = $.extend(true, {}, query)
          if cquery and cquery.criteria
            _.each cquery.criteria, (criteria, id) =>
              if criteria.isset
                cquery.criteria[id].isset = 0
          else
            cquery = {"logic":"and","criteria":[{"type":"frame","isset":0,"name":key}]}

          @_update(@emptyCollection, {sortkey:key, sortorder:direction, query:cquery}, true, false)
          @_update(@collection, {sortkey:key, sortorder:direction, query:query}, true)
        else # We can show everything
          if query and query.criteria
            _.each query.criteria, (criteria, id) =>
              if criteria.isset
                delete(query.criteria[id])
            query.criteria = _.compact(query.criteria)
          @collection = @_update(@collection, {sortkey:key, sortorder:direction, query:query})
      else # Show empty rows
        @collection = @_update(@collection, {sortkey:key, sortorder:direction})

    else if @settings.sorttype is 'js' # Let javascript do the sorting
      @variables.clearrows = true
      @variables.cleardata = true
      @variables.skip = 0
      @sortedCollection = new Backbone.Collection(@variables.data, {model: @settings.model})
      if @settings.model
        model = @settings.model
        spl = key.split(".")
        if direction is 1
          @sortedCollection.comparator = (model) ->
            str = model.get(spl[0])[spl[1]] ? ""
            str = str.toString()
            return str
        else if direction is -1
          @sortedCollection.comparator = (model) ->
            str = model.get(spl[0])[spl[1]] ? ""
            str = str.toString()
            if !str
              str = "                                                                                                                                 "
            return str
        @sortedCollection.sort()
        if direction is -1
          @sortedCollection.models.reverse()
        @variables.data = _.clone @sortedCollection.models
        @variables.rows = []
        if @variables.navigateId
          page = Math.floor(@variables.navigateId / @settings.limit)
          mod = @variables.navigateId % @settings.limit
          if mod
              page++
          if page == 1
            @variables.skip = 0
          else
            @variables.skip = page * @settings.limit - @settings.limit
        for o,i in @variables.data
          if @settings.pagination == "num"
            if i >= @variables.skip and i < @settings.limit + @variables.skip
              if @variables.direction is 1
                @variables.rows.unshift(@_row(o))
              else
                @variables.rows.push(@_row(o))
          else
            if @variables.direction is 1
              @variables.rows.unshift(@_row(o))
            else
              @variables.rows.push(@_row(o))
        @render()

  _page: (e) =>
    page = $(e.target).data('page')
    if page > 0
      if page is 1
        @variables.skip = 0
      else
        @variables.skip = page * @settings.limit - @settings.limit
      @variables.rows = []
      for o,i in @variables.data
        if i >= @variables.skip and i < @settings.limit + @variables.skip
          if @variables.direction is 1
            @variables.rows.unshift(@_row(o))
          else
            @variables.rows.push(@_row(o))
      @variables.page = page
      @render()

  _infinite: =>
    if @collection and @collection.lastavail >= @variables.limit
      @variables.skip += @variables.limit
      @collection.setParam 'skip', @variables.skip
      @variables.clearrows = true
      @variables.cleardata = false
      @collection.fetch()
    return

  _scroll: (y) =>
    if @settings.header is 'float'
      if !@variables.scroll
        @variables.scroll = $(@variables.scrollElem)
      @_scrollLeft()
      @_scrollDown()

  _scrollLeft: () =>
    left = @variables.scroll.scrollLeft()
    if left != @variables.left
      @variables.left = left
      offset = @$el.find('.table.static thead').offset()
      head = @$el.find('.header')
      head.css('left', offset.left)

  _scrollDown: () =>
    down = @variables.scroll.scrollTop()
    head = @$el.find('.header')
    if down > 0
      if !head.hasClass('shadow')
        head.addClass('shadow')
    else
      if head.hasClass('shadow')
        head.removeClass('shadow')

  reflow: =>
    super()
    if @settings.header is 'float'
      @_header()

  # Handles downloading collections by file type
  _download: (e) =>
    type = $(e.target).attr('data-type')
    if @collection
      @collection.setParam 'limit', 999999999
      url = @collection.baseUrl + @collection.getUrl()
      s = url.split("?")
      s[0] += "/format/" + type
      url = s.join("?")
      @collection.setParam 'limit', @variables.limit
      window.open(encodeURI(url))
    return false

  # Toggles settings menu
  _toggles: (e) =>
    box = $('.toggles-html')
    if box.is(":visible")
      box.fadeOut(150)
    else
      box.fadeIn(150)

  # Toggles toggle 
  _toggle: (e) =>
    key = $(e.currentTarget).data('key')
    value = $(e.currentTarget).attr('checked')
    if key
      for o,i in @settings.columns 
        if o.data.key is key
          if value
            o.visible = true
          else
            o.visible = false
      @_data()
