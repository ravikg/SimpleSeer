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
    # editable: (true), false

    # Build everything
    @settings = @_settings()
    @variables = @_variables()
    @template = @variables.template
    @collection = @_collection()

    if @settings.pagination is 'infinite'
      @on 'page', @_infinite
    if @settings.header is 'float'
      @on 'scroll', @_scroll

    # Init table
    @collection.fetch()

  # Build a settings object from our configuration file
  _settings: =>
    settings = {}
    settings.classes = ['table', 'border', 'zebra']
    settings.styles = []
    settings.size = @options.size ? 'full'
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
      settings.limit = @options.data.limit ? 40
      settings.limit = 40
    settings.subscribe = @options.subscribe ? []
    settings.columns = @options.columns ? []
    settings.sortable = @options.sortable ? true
    settings.sorttype = @options.sorttype ? 'db'
    if settings.sortable
      for o,i in settings.columns
        o.sortable = o.sortable ? true

    return settings

  # Append addition variables to our class scope
  _variables: =>
    variables = super()
    variables.template = TableTemplate
    variables.rowTemplate = RowTemplate
    variables.preHTML = ""
    variables.postHTML = ""
    variables.data = []
    variables.cleardata = false
    variables.rows = []
    variables.clearrows = false
    variables.sortkey = undefined
    variables.sortdirection = -1
    variables.limit = @settings.limit
    variables.skip = 0
    variables.nodata = false
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

  # Build the collection and fetch the initial batch
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

  _update: (params) =>
    if @collection
      for i,o of params
        @collection.setParam i, o

      @collection.fetch()
    else
      @_collection()

  _clear: =>
    if @variables.cleardata
      @variables.data = []
      @variables.cleardata = false
    if @variables.clearrows
      @variables.rows = []
      @variables.clearrows = false

  ''' RENDERING '''

  _data: (a = null, b = null) =>
    console.log _.clone @collection.url


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
        console.log "data length", data.length
        @variables.data = @variables.data.concat(data)
        console.log "variables data length", @variables.data.length
        console.log "rows before length", @variables.rows.length
        for o,i in @variables.data
          if @variables.direction is 1
            @variables.rows.unshift(@_row(o))
          else
            @variables.rows.push(@_row(o))
        console.log "rows after length", @variables.rows.length
        @render()
    else
      @variables.data = []
      @variables.rows = []
      @$el.find('.table.static tbody').html('<tr><td class="nodata" colspan="' + @settings.columns.length + '">No data within filter parameters</td></tr>')

  # Generally overwrite in client repo
  _formatData: (data) =>
    return data

  _row: (row = {}) =>
    return @variables.rowTemplate @_formatRow(row)

  _formatRow: (row) =>
    id = row.get('id') ? ''
    values = []

    for o,i in @settings.columns
      values.push @_formatCell o, row.get(o.data.key)

    return {id: id, values: values}

  _formatCell: (settings, value) =>
    cell = {title:'', html:'', data:[]}
    
    for i,o of settings.data
      cell.data.push('data-'+i+'="'+o+'"')
    
    cell.raw = value
    cell.html = value
    return cell

  getRenderData: =>
    classes: @settings.classes
    styles: @settings.styles
    header: @variables.preHTML
    footer: @variables.postHTML
    columns: @settings.columns
    rows: @variables.rows
    pageButtons: @options.page == "page"

  afterRender: =>
    dir = (if @variables.sortdirection is -1 then "asc" else "desc")
    @$el.find(".th[data-key=\"#{@variables.sortkey}\"]")
      .removeClass("sort-asc sort-desc")
      .addClass("sort-#{dir}")

    if @settings.header is 'float'
      @_header()
      if !@variables.scroll
        @variables.scroll = $(@variables.scrollElem)
      console.log "trying to scroll left"
      @_scrollLeft()

  _header: () =>
    console.log "header"
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



  ''' EVENT HANDLING '''

  events: =>
    "click th.sortable":"_sort"
    #"click .showhidden .button":"showHiddenEvent"
    #"click .downloads button":"downloadData"
    #"click .show-hide-button":"showHideEvent"
    #"click .show-hide-checkbox":"showHideCheckboxEvent"

  _sort: (e) =>
    direction = @variables.sortdirection
    type = (if e.currentTarget then 'event' else 'filter')
    if type is 'event'
      key = $(e.currentTarget).data('key')
      if direction is 1
        @variables.sortdirection = -1
      else
        @variables.sortdirection = 1
    else if type is 'filter'
      if direction = 1
        direction = -1
      else
        direction = 1
      key = $(e).data('key')

    @variables.sortkey = key

    if @settings.sorttype is 'db' # Let the backend do the sorting
      @variables.clearrows = true
      @variables.cleardata = true
      @_update({sortkey:key, sortorder:direction})
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
      console.log "Scrolling left"
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
    if @settings.header is 'float'
      @_header()





  showHideEvent: (e) =>
    box = $('.show-hide')
    if box.is(":visible")
      box.fadeOut(150)
    else
      box.fadeIn(150)

  showHideCheckboxEvent: (e) =>
    key = $(e.target).val()
    checked = $(e.target).attr('checked')
    if checked
      @showHideColsSelected[key] = 0
    else
      @showHideColsSelected[key] = 1
    $("th[data-key=\"#{key}\"], td.#{key}").toggleClass('hidden')
    if e.originalEvent?
      $(window).resize()

  getColumnKeyByTitle: (title) =>
    key = null
    _.each @tableCols, (col) =>
      if col.title == title
        key = col.key

    return key

  getColumnTitleByKey: (key) =>
    title = null
    _.each @tableCols, (col) =>
      if col.key == key
        title = col.title

    return title

  getOptions: =>
    return

  getCollectionExtras: =>
    return

  

  receive: (data) =>
    poo = @collection.where({id: data.data.id})[0]
    if data.channel == "framedelete/"
      if model? then @collection.remove(model)
    if data.channel == "frameupdate/"
      if model? then model.attributes = data.data
      else @collection.add(data.data, {at: 0})
    @updateData()
    #@render()

  emptyData: =>
    if @emptyCollection
      if !@emptyCollection.length
        @hasHidden = false
      else if @emptyCollection.length == 1
        if @emptyCollection.models and @emptyCollection.models[0] and @emptyCollection.models[0].attributes
          if !@emptyCollection.models[0].attributes.id
            @hasHidden = false
          else
            @hasHidden = true
      else
        @hasHidden = true
    else if @emptyCollection.length > 1
      @hasHidden = false
    @collection.fetch({'filtered':true})

  getEmptyCollection: (key, cquery) =>
    if @collection and !@showHidden
      @emptyCollection = new @_collection([],{model:@_model,clearOnFetch:@cof,url:@_url,viewid:@viewid})
      @emptyCollection.setParam 'sortkey', @getSortKey(@sortKey)
      @emptyCollection.setParam 'sortorder', @direction
      @emptyCollection.setParam 'limit', @limit

      if cquery and cquery.criteria
        _.each cquery.criteria, (criteria, id) =>
          if criteria.isset
            cquery.criteria[id].isset = 0
      else
        cquery = {"logic":"and","criteria":[{"type":"frame","isset":0,"name":key}]}

      @emptyCollection.setParam 'query', cquery
      if @columnSortType == 'measurement'
        @emptyCollection.setParam 'sorttype', 'measurchement'
      @emptyCollection.fetch({'async':false, success:@emptyData})

  subscribe: (channel="") =>
    if channel
      namePath = channel + "/"
      if application.socket
        application.socket.removeListener "message:#Chart/#{namePath}", @chartCheck
        application.socket.on "message:Chart/#{namePath}", @chartCheck
        #console.info "binding to: message:Chart/#{namePath}"
        if !application.subscriptions["Chart/#{namePath}"]
          #console.info "subscribing to: #{@subscribePath}/#{namePath}"
          application.subscriptions["Chart/#{namePath}"] = application.socket.emit 'subscribe', "Chart/#{namePath}"



  isEditable:(cols, key) =>
    edit = 0
    $.each cols, (k, v) ->
      if v.key == key
        if v.editable? and v.editable
          edit++
    return (if edit then true else false)

  subCols:(key) =>
    subCols = undefined
    $.each @tableCols, (k, v) ->
      if v.key == key
        if v.subcols
          subCols = v.subcols
    return subCols

  editableCell: =>
    ###
       $(".td").dblclick ->
        handleReset = (e, key) ->
          if key and e.which is 27
            self = $(this).parent().removeClass("edit")
            ret = $(this).attr("value")
            span = $("<span/>").attr("title", ret).html(ret)
            self.html("").append(span).attr "title", ret
          else if (key and e.which is 13) or not key
            self = $(this).parent().removeClass("edit")
            ret = $(this).get(0).value
            span = $("<span/>").attr("title", ret).html(ret)
            self.html("").append(span).attr "title", ret
        return false  if editableTable is false
        self = $(this).addClass("edit")
        text = self.get(0).firstChild.innerHTML
        input = $("<input>").attr("type", "text").attr("value", text)
        input.blur (e) ->
          handleReset.call this, e, false

        input.keyup (e) ->
          handleReset.call this, e, true

        self.html("").append input
        input.focus()
    ###

  # Returns the tableCol given a key
  getTableCol: (cols, key) =>
    col = null
    _.each cols, (a, b) =>
      if a.key == key
        col = a
    return col

  # Render the cell
  renderCell:(raw, key, inspection_id = '') =>
    v = raw
    html = ''
    tableCol = @getTableCol(@tableCols, key)

    # Generate the html
    if typeof v == 'object' # Complicated render
      if tableCol.editable
        if tableCol.subCols
          _.each tableCol.subCols, (a, b) =>
            col = a
            if col.editable # Sub column is editable
              value = ''
              placeholder = if col.placeholder then col.placeholder else col.title
              _.each v, (field) =>
                if field.key == col.key
                  value = field.value
              args = {
                placeholder: placeholder
                type: 'text'
                name: key + '-' + col.key
                value: value
                class: key + '-' + col.key
                'data-inspection-id': inspection_id
              }
              html += "<input "
              $.each args, (k, v) =>
                html += k + '="' + v + '" '
              html += "/>"
        else
          col = tableCol
          if col.editable # Sub column is editable
            value = ''
            placeholder = if col.placeholder then col.placeholder else col.title
            _.each v, (field) =>
              if field.key == col.key
                value = field.value
            args = {
              placeholder: placeholder
              type: 'text'
              name: col.key
              value: value
              class: col.key
            }
            html += "<input "
            $.each args, (k, v) =>
              html += k + '="' + v + '" '
            html += "/>"
      else # Not editable, return self
        v = v
    else # Simple render
      v = v

    if !html
      html = v

    value =
      html: html
      raw: raw
    return value

  changeCell:(e) =>
    target = $(e.target)
    id = target.parents('tr').attr('id')
    part = target.parents('tr').data('part')
    cls = target.attr('class')
    measurement_id = target.data('measurement-id')
    tolerance_id = target.data('tolerance-id')
    spl = cls.split('-')
    if spl[0]
      key = spl[0]
    if spl[1]
      subkey = spl[1]
    title = @getColumnTitleByKey(key)
    value = target.val()

    obj = {}
    if target then obj.target = target
    if id then obj.id = id
    if cls then obj.cls = cls
    if key then obj.key = key
    if subkey then obj.subkey = subkey
    if title then obj.title = title
    if value then obj.value = value
    if measurement_id then obj.measurement_id = measurement_id
    if tolerance_id then  obj.tolerance_id = tolerance_id
    if part then obj.part = part

    @saveCell(obj)

  saveCell:(frame, obj, key = '') =>
    frame.save if key then {key: obj} else obj





  getSortKey: (k) =>
    key = k
    key = if k is "capturetime" then 'capturetime_epoch' else key
    return key

  downloadData: (e) =>
    if @collection
      type = $(e.target).attr('data-type')
      @collection.setParam 'limit', 999999999
      url = @collection.baseUrl + @collection.getUrl()
      s = url.split("?")
      s[0] += "/format/" + type
      url = s.join("?")
      @collection.setParam 'limit', @limit
      window.open(encodeURI(url))
    return false

  showHiddenEvent: (e) =>
    @showHidden = true
    query = @collection.getParam 'query'
    if @showHidden
      if query.criteria
        _.each query.criteria, (criteria, id) =>
          if criteria.isset
            delete(query.criteria[id])
      query.criteria = _.compact(query.criteria)
      @collection.setParam 'query', query
      @collection.fetch({'filtered':true})





  infinitePage: =>
    if @collection and @collection.lastavail >= @limit
      @left = undefined
      @collection.setParam('skip', (@collection.getParam('skip') + @limit))
      @collection.fetch()
    return

  updateShowHide: =>

    keys = {}

    @$("table.table.static thead th").each (i, o)->
      keys[$(o).data('key')] = 0

    for row in @data
      for key,value of keys
        if row[key]
          delete keys[key]

    #i = 1
    #for k,v of keys
    #  total = $("table.table.static td:nth-child(#{i})").length
    #  empty = $("table.table.static td:nth-child(#{i}):empty").length
    #  if total == empty
    #    keys[k] = 1
    #  i++

    # If there is a small data set, let's just show everything off the bat to avoid confusion
    # for new applications.  Also, if at this point keys.length == tablecols.length then that
    # means that every column is hidden, which would seem confusing. So, lets show those cols!
    if @tableCols.length == keys.length
      delete keys
      keys = {}

    if @data.length < 20
      delete keys
      keys = {}

    for k,v of keys
      $("input#show-hide-#{k}").click()


  reflow: =>
    super()
    @updateHeader()

  scrollLeft: (per) =>
    l = @scroll.scrollLeft()
    if l != @left
      @left = l
      offset = @static.offset()
      if @firefox or @msie
        @head.css('left', offset.left - 1)
      else
        @head.css('left', offset.left)

  scrollDown: (per) =>
    d = @scroll.scrollTop()
    if d > 0
      if !@head.hasClass('shadow')
        @head.addClass('shadow')
    else
      if @head.hasClass('shadow')
        @head.removeClass('shadow')

  scrollPage: (per) =>
    if @persistentHeader
      if !@scroll
        @scroll = $(@scrollElem)
      @scrollLeft(per)
      @scrollDown(per)
