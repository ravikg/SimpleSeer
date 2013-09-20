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
      settings.limit = 100
    settings.subscribe = @options.subscribe ? []
    settings.columns = @options.columns ? []
    settings.sortable = @options.sortable ? true
    settings.sorttype = @options.sorttype ? 'db'
    if settings.sortable
      for o,i in settings.columns
        o.sortable = o.sortable ? true
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
    if @settings.header is 'float'
      variables.preHTML += '<div class="header">
              <div class="float">
                <table class="table floater borderTop"></table>
              </div>
            </div>'

    return variables



  ''' GETTING / SETTING DATA '''

  # Build the collection and return it
  _collection: =>
    bindFilter = Application.context[@options.parent.dashboard.options.parent.options.context].filtercollection
    collection = new @settings.collection([], {
      bindFilter: bindFilter, 
      model: @settings.model, 
      url: @settings.url, 
      viewid: @settings.viewid
    })

    collection.setParam 'limit', @variables.limit
    collection.setParam 'skip', @variables.skip

    for o,i in @settings.subscribe
      collection.subscribePath = o
      collection.subscribe(false,@receive)

    collection.on('reset', @_data)
    return collection

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

  # Handles data messages from socket
  receive: (data) =>
    model = @collection.where({id: data.data.id})[0]
    if data.channel == "framedelete/"
      if model then @collection.remove(model)
    if data.channel == "frameupdate/"
      if model then model.attributes = data.data
      else @collection.add(data.data, {at: 0})
    @_data()



  ''' RENDERING '''

  # Main data render trigger function
  _data: (a = null, b = null) =>
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
      if @collection.models and @collection.models[0] and @collection.models[0].get('id')
        @variables.nodata = false
      else
        @variables.nodata = true
    else
      @variables.nodata = false

    if !@variables.nodata
      data = @_formatData @collection.models
      if data
        @variables.data = @variables.data.concat(data)
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
      cell.href = settings.href

    return cell

  # Add stuff to the render function
  render: =>
    if @settings.size is 'full'
      @select()
      super()
      @

  # Pass data to handlebars to render
  getRenderData: =>
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
      if @settings.model
        model = @settings.model
        
        if direction is 1
          @collection.comparator = (model) ->
            str = model.get(key) ? ""
            str = str.toString()
            String.fromCharCode.apply String, _.map(str.split(""), (c) ->
              c.charCodeAt() - 0xffff
            )
        else if direction is -1
          @collection.comparator = (model) ->
            str = model.get(key) ? ""
            str = str.toString()
            if !str
              str = "                                                                                                                                 "
            String.fromCharCode.apply String, _.map(str.split(""), (c) ->
              0xffff - c.charCodeAt()
            )
        @collection.models = @variables.data
        @collection.sort()

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
    if @collection
      type = $(e.target).attr('data-type')
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
