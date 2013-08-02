Application = require 'application'
SubView = require 'views/core/subview'
Template = require './templates/table2'
RowTemplate = require './templates/row2'
Collection = require "collections/table"

module.exports = class Table extends SubView
  template: Template
  rowTemplate: RowTemplate

  tbody: {}
  thead: {}
  content: {}
  widthCache: {}
  editableList:{}
  sortKey: 'id'
  sortDirection: 'desc'
  lastSortKey: undefined
  cof: false
  editable: true
  renderComplete: false
  lastY: 0
  limit: 100
  direction: -1
  insertDirection: -1
  sortType: 'collection'
  header: ''
  tableClasses: 'table'
  firefox: false
  msie: false
  left: undefined
  persistentHeader: false
  showHidden: false
  hasHidden: false
  noData: false
  showHideCols: {}
  showHideColsSelected: {}
  scrollElem: '#content #slides'
  afterRenderCounter: 0
  viewid: "5089a6d31d41c855e4628fb0"
  noRender: false

  events: =>
    "click th.sortable":"sortByColumn"
    "click .showhidden .controlButton":"showHiddenEvent"
    "click .downloads button":"downloadData"
    "click .show-hide-button":"showHideEvent"
    "click .show-hide-checkbox":"showHideCheckboxEvent"

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

  initialize: =>
    super()
    # @Todo: Standardize and push this up the chain
    @msie = $.browser.hasOwnProperty('msie')
    @firefox = $.browser.hasOwnProperty('mozilla')

    @rows = []
    @getOptions()
    @getCollection()
    if @infiniteScrollEnabled
      @on 'page', @infinitePage
    #@scroll = $(@scrollElem)
    if @persistentHeader
      @on 'scroll', @scrollPage

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
    if @options.persistentHeader?
      @persistentHeader = @options.persistentHeader
    if @options.infiniteScroll?
      @infiniteScrollEnabled = @options.infiniteScroll
    if @options.sortKey?
      @sortKey = @options.sortKey
    if @options.sortDirection?
      @direction = @options.sortDirection
      if @direction == 1
        @sortDirection = 'asc'
      else
        @sortDirection = 'desc'
    if @options.sortType?
      @sortType = @options.sortType
    if @options.tableKey?
      @tableKey = @options.tableKey
    if @options.editable?
      @editable = @options.editable
    if !@options.tableCols?
      @tableCols = [key: "id", title: "ID"]
    else
      @tableCols = @options.tableCols
    if @options.collection_model
      @_collection = require "collections/" + @options.collection_model + "s"
      @_model = require "models/" + @options.collection_model
      @_url = "api/"+@options.collection_model
    else
      @_collection = require "collections/table"
      @_model = require "models/frame"
      @_url = "api/frame"

  getCollectionExtras: =>
    return

  getCollection: =>
    bindFilter = Application.context[@options.parent.dashboard.options.parent.options.context].filtercollection
    @collection = new @_collection([],{bindFilter:bindFilter,model:@_model,clearOnFetch:@cof,url:@_url,viewid:@viewid})
    if !@options.collection_model
      @collection.setParam 'sortkey', @getSortKey(@sortKey)
      @collection.setParam 'sortorder', @direction
      @collection.setParam 'limit', @limit
    @getCollectionExtras()
    @collection.subscribePath = "frameupdate"
    @collection.subscribe(false,@receive)
    @collection.subscribePath = "framedelete"
    @collection.subscribe(false,@receive)
    @collection.on('reset',@updateData)
    @collection.fetch()
    @subscribe()

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
      @emptyCollection.fetch({'async':false, modal:success:@emptyData})

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

  getRenderData: =>
    classes: @tableClasses
    header: @header
    cols: @tableCols
    rows: @rows
    pageButtons: @options.page == "page"

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
  renderCell:(raw, key) =>
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
    cls = target.attr('class')
    spl = cls.split('-')
    if spl[0]
      key = spl[0]
    if spl[1]
      subkey = spl[1]
    title = @getColumnTitleByKey(key)
    value = target.val()

    obj =
      target: target
      id: id
      cls: cls
      key: key
      subkey: subkey
      title: title
      value: value
    @saveCell(obj)

  saveCell:(frame, obj, key = '') =>
    frame.save if key then {key: obj} else obj

  renderRow:(row) =>
    values = []
    classes = if row.classes then row.classes else {}
    titles = if row.titles then row.titles else {}
    id = if row.id then row.id else ''

    _.each @tableCols, (v, k) =>
      key = v.key
      val = row[v.key]
      value = @renderCell(val, key)
      cls = v.key
      title = ""
      if classes and classes[key]
        cls += ' ' + classes[key]
      if titles and titles[key]
        title = titles[key]
      values.push {'class' : cls, 'value' : value, 'title' : title}

    return {id: row.id, values: values}

  insertRow:(row, insertDirection = 1) =>
    markup = @rowTemplate @renderRow(row)
    if insertDirection is -1
      @rows.push(markup)
    else
      @rows.unshift(markup)

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

  sortByColumn:(e, set) =>
    if @sortType is 'collection'
      key = $(e.currentTarget).data('key')
      direction = $(e.currentTarget).attr('direction') || "desc"
      if @lastSortKey and key != @lastSortKey
        @showHidden = false
      if key
        @lastSortKey = key
      k = @getSortKey(key)
      if !set
        @collection.setParam 'sortkey', k
      @sortKey = key
      if direction == "asc"
        @collection.setParam 'sortorder', -1
        @sortDirection = 'desc'
        @direction = -1
      else
        @collection.setParam 'sortorder', 1
        @sortDirection = 'asc'
        @direction = 1
      @cof = true
      query = @collection.getParam 'query'
      if @showHidden
        if query.criteria
          _.each query.criteria, (criteria, id) =>
            if criteria.isset
              delete(query.criteria[id])
        query.criteria = _.compact(query.criteria)
        @collection.setParam 'query', query
        @collection.fetch({'filtered':true})
      else
        if query
          if query.criteria
            _.each query.criteria, (criteria, id) =>
              if criteria.isset
                delete(query.criteria[id])
            query.criteria.push({"type":"frame","isset":1,"name":k})
            query.criteria = _.compact(query.criteria)
          else
            query = {"logic":"and","criteria":[{"type":"frame","isset":1,"name":k}]}
          @collection.setParam 'query', query
        else
          query = {"logic":"and","criteria":[{"type":"frame","isset":1,"name":k}]}
          @collection.setParam 'query', query
        cquery = $.extend(true, {}, query);
        @getEmptyCollection(k, cquery)
    else if @sortType is 'js'
      key = $(e.currentTarget).data('key')
      direction = $(e.currentTarget).attr('direction') || "desc"
      if key
        @lastSortKey = key
      @sortKey = key
      k = @getSortKey(key)
      if direction == "asc"
        @sortDirection = 'desc'
        @direction = -1
      else
        @sortDirection = 'asc'
        @direction = 1
      if @model
        if @direction == 1
          @collection.comparator = (@model) =>
            String.fromCharCode.apply String, _.map(@model.get(k).split(""), (c) ->
                c.charCodeAt() - 0xffff
              )
        else if @direction == -1
          @collection.comparator = (@model) =>
            String.fromCharCode.apply String, _.map(@model.get(k).split(""), (c) ->
                0xffff - c.charCodeAt()
              )
        @collection.sort()
        @updateData()

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

  formatData:(data) =>
    return data

  updateData: =>
    if @cof == true
      @scroll.scrollTop(0)
      @cof = false
    @rows = []
    if @collection
      if !@collection.length
        @noData = true
      else if @collection.length == 1
        if @collection.models and @collection.models[0] and @collection.models[0].attributes
          if !@collection.models[0].attributes.id
            @noData = true
          else
            @noData = false
      else
        @noData = false
    else
      @noData = false
    if @collection and @collection.models
      data = @formatData @collection.models
    else
      data = @formatData @tableData
    if data.length
      @noData = false
    @data = data
    if !@noData
      _.each data, (model) =>
        @insertRow(model, @insertDirection)
    @render()

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

  updateHeader: =>
    if @persistentHeader
      @$(".table.floater").html('')
      @$(".table.static .thead").clone().appendTo('.table.floater').css('opacity', 1)
      @head = @$(".header")
      @static = @$(".table.static .thead")
      @floater = @$(".table.floater .thead")
      @table = @$(".table.static")
      @controls = @table.hasClass('controls')

      # Some extra nudging
      extras = {'w':0, 'h':0, 't':0, 'l':0}
      if @controls
        extras.w = 4
        extras.h = 0
        extras.t = -8
        extras.l = 0

      @hider = @$('.hider')

      @hider.width(@static.width() + 12)
      @head.width(@static.width() + 1).css('top', 68)
      @hider.css('left', @head.offset().left - 10)

      key = undefined
      last = undefined
      w = undefined
      _.each @static.find('.th'), (column) =>
        col = $(column)
        key = col.attr('data-key')
        width = col.width()
        place = col.find('.placeholder')
        p = $(place)
        pwidth = p.width()
        ppadleft = parseInt(p.css('padding-left'), 10)
        ppadright = parseInt(p.css('padding-right'), 10)
        w = pwidth + ppadleft + ppadright + 1 + extras.w
        h = col.height() + extras.h
        if col.is(":visible")
          last = key
        @floater.find(".th[data-key=#{key}]").css('width', w).css('height', h - 2)

      if last
        item = @floater.find(".th[data-key=#{last}]")
        item.css('width', item.width() - 1)
      @table.css('position', 'relative').css('top', 36)

  afterRender: =>

    @afterRenderCounter++

    @$el.find(".th[data-key=#{@sortKey}]")
      .removeClass("sort-asc sort-desc")
      .addClass("sort-#{@sortDirection}")
      .attr('direction', @sortDirection)

    if !@scroll
      @scroll = $(@scrollElem)

    if @afterRenderCounter >= 2
      @updateShowHide()
    @updateHeader()
    @scrollPage(0)

    # Shows a placeholder row, that asks the user if they would like to see the hidden rows on sort
    if !@showHidden and @hasHidden
      cols = @tableCols.length
      $(".table.static tbody").prepend('<tr><td class="td showhidden" colspan="'+cols+'"><span class="controlButton">Show hidden rows?</span></td></tr>')

    # Shows the row if there is no data
    if @noData
      cols = @tableCols.length
      $(".table.static tbody").prepend('<tr><td class="td showhidden" colspan="'+cols+'">No data to display. Try expanding your filters.</td></tr>')

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
