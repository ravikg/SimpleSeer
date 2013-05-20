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
  scrollElem: '#content #slides'
  viewid: "5089a6d31d41c855e4628fb0"

  events: =>
    "click th.sortable":"sortByColumn"
    "change input":"changeCell"
    "click .showhidden .controlButton":"showHiddenEvent"
    "click .downloads .controlButton":"downloadData"

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
    if @options.sortKey?
      @sortKey = @options.sortKey
    if @options.sortDirection?
      @direction = @options.sortDirection
      if @direction == 1
        @sortDirection = 'asc'
      else
        @sortDirection = 'desc'
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

  getCollection: =>
    bindFilter = Application.context[@options.parent.dashboard.options.parent.options.context].filtercollection
    @collection = new @_collection([],{bindFilter:bindFilter,model:@_model,clearOnFetch:@cof,url:@_url,viewid:@viewid})
    if !@options.collection_model
      @collection.setParam 'sortkey', @getSortKey(@sortKey)
      @collection.setParam 'sortorder', @direction
      @collection.setParam 'limit', @limit
    @collection.on('reset',@updateData)
    @collection.fetch()
    @subscribe()

  emptyData: =>
    if @emptyCollection.length > 1
      @hasHidden = true
    @collection.fetch({'filtered':true})

  getEmptyCollection: (key) =>
    if @collection and !@showHidden
      @emptyCollection = new @_collection([],{model:@_model,clearOnFetch:@cof,url:@_url,viewid:@viewid})
      @emptyCollection.setParam 'sortkey', @getSortKey(@sortKey)
      @emptyCollection.setParam 'sortorder', @direction
      @emptyCollection.setParam 'limit', @limit
      @emptyCollection.setParam 'query', {"logic":"and","criteria":[{"type":"frame","isset":0,"name":key}]}
      @emptyCollection.on('reset',@emptyData)
      @emptyCollection.fetch({'async':false})

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

  initialize: =>
    super()
    # @Todo: Standardize and push this up the chain
    @msie = $.browser.hasOwnProperty('msie')
    @firefox = $.browser.hasOwnProperty('mozilla')

    @rows = []
    @getOptions()
    @getCollection()
    @on 'page', @infinitePage
    @scroll = $(@scrollElem)
    if @persistentHeader
      @on 'scroll', @scrollPage

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
    id = if row.id then row.id else ''

    _.each @tableCols, (v, k) =>
      key = v.key
      val = row[v.key]
      value = @renderCell(val, key)
      cls = v.key
      if classes and classes[key]
        cls += ' ' + classes[key]
      values.push {'class' : cls, 'value' : value}

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
    key = $(e.currentTarget).data('key')
    direction = $(e.currentTarget).attr('direction') || "desc"
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
    if @showHidden
      @collection.setParam 'query', {}
      @collection.fetch({'filtered':true})
    else
      @collection.setParam 'query', {"logic":"and","criteria":[{"type":"frame","isset":1,"name":k}]}
      @getEmptyCollection(k)

  showHiddenEvent: (e) =>
    @showHidden = true
    @collection.setParam 'query', {}
    @collection.fetch({'filtered':true})

  formatData:(data) =>
    return data

  render: =>
    super()

  updateData: =>
    if @cof == true
      @scroll.scrollTop(0)
      @cof = false
    @rows = []
    if @collection and !@collection.length
      @noData = true
    else
      @noData = false
    if @collection and @collection.models
      @tableData = @collection.models
    data = @formatData(@tableData)
    _.each data, (model) =>
      @insertRow(model, @insertDirection)
    @render()

  infinitePage: =>
    if @collection and @collection.lastavail >= @limit
      @collection.setParam('skip', (@collection.getParam('skip') + @limit))
      @collection.fetch()

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
      @head.width(@static.width() + 1)
      @hider.css('left', @head.offset().left - 10)

      key = undefined
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
        @floater.find(".th[data-key=#{key}]").css('width', w).css('height', h)

      @floater.find(".th[data-key=#{key}]").css('width', w - 2)
      @table.css('position', 'relative').css('top', @head.height() - @floater.height() + extras.t)

  afterRender: =>

    @$el.find(".th[data-key=#{@sortKey}]")
      .removeClass("sort-asc sort-desc")
      .addClass("sort-#{@sortDirection}")
      .attr('direction', @sortDirection)

    if !@scroll
      @scroll = $(@scrollElem)

    @updateHeader()

    # Shows a placeholder row, that asks the user if they would like to see the hidden rows on sort
    if !@showHidden and @hasHidden
      cols = @tableCols.length
      $(".table.static tbody").prepend('<tr><td class="td showhidden" colspan="'+cols+'"><span class="controlButton">Show hidden rows?</span></td></tr>')

    # Shows the row if there is no data
    if @noData
      cols = @tableCols.length
      $(".table.static tbody").prepend('<tr><td class="td showhidden" colspan="'+cols+'">There was no data. Try expanding your filters.</td></tr>')

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
    if !@scroll
      @scroll = $(@scrollElem)
    @scrollLeft(per)
    @scrollDown(per)