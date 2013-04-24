Application = require 'application'
SubView = require 'views/core/subview'
Template = require './templates/table'
RowTemplate = require './templates/row'
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
  limit: 50
  direction: -1
  insertDirection: -1
  scrollThreshold: 4
  sortType: 'collection'
  header: ''
  tableClasses: 'table'

  events: =>
    "click .th" : "sortByColumn"
    "change .tbody input" : "changeCell"

  onScroll:(per) => @pollShadow()

  onPage: => @infinitePage()

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
    @collection = new @_collection([],{model:@_model,clearOnFetch:@cof,url:@_url})
    if !@options.collection_model
      if @sortKey == 'capturetime'
        @collection.setParam 'sortkey', 'capturetime_epoch'
      else
        @collection.setParam 'sortkey', @sortKey
      @collection.setParam 'sortorder', @direction
    @collection.fetch({'success':@updateData})

  initialize: =>
    super()
    @rows = []
    @getOptions()
    @getCollection()

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
          html += '<div class="subCols">'
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
              html += '<div class="subCol">'
              html += "<input "
              $.each args, (k, v) =>
                html += k + '="' + v + '" '
              html += "/></div>"
          html += '</div>'
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

  # Default saveCell functionality
  saveCell: (obj) =>
    return

  changeCell:(e) => # @TODO: DO THIS TOMORROW
    target = $(e.target)
    id = target.parents('div.tr').attr('id')
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

    _.each @tableCols, (v, k) =>
      key = v.key
      val = row[v.key]
      value = @renderCell(val, key)
      values.push {'class' : v.key, 'value' : value}

    return {id: row.id, values: values}

  insertRow:(row, insertDirection = 1) =>
    markup = @rowTemplate @renderRow(row)
    if insertDirection is -1
      @rows.unshift(markup)
    else
      @rows.push(markup)

  sortByColumn:(e, set) =>
    key = $(e.currentTarget).data('key')
    direction = $(e.currentTarget).attr('direction') || "desc"
    if !set
      @collection.setParam 'sortkey', if key is "capturetime" then 'capturetime_epoch' else key
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
    @collection.fetch
      filtered:true

  formatData:(data) =>
    return data

  updateData: =>
    @rows = [] 
    if !@tableData and @collection and @collection.models
      @tableData = @collection.models
    data = @formatData(@tableData)
    _.each data, (model) =>
      @insertRow(model, @insertDirection)
    @render()
    @packTable()

  infinitePage: =>
    if @collection.lastavail >= @limit
      @collection.setParam('skip', (@collection.getParam('skip') + @limit))
      @collection.fetch()

  afterRender: =>
    $(window).resize( _.debounce @packTable, 100 )
    @$el.find(".th[data-key=#{@sortKey}]")
      .removeClass("sort-asc sort-desc")
      .addClass("sort-#{@sortDirection}")
      .attr('direction', @sortDirection)
    @thead = @$(".thead")
    @tbody = @$(".tbody").infiniteScroll {
      onPage: => @onPage()
      onScroll: => @onScroll()
    }
    @content = @tbody.find(".tscroll")
    @tbody.scrollTop(@lastY) if @lastY
    @packTable()

  reflow: =>
    super()
    @packTable()

  pollShadow: =>
    @lastY = top = @tbody.scrollTop()
    @thead.removeClass("shadow")
    @thead.addClass("shadow") if top > 0

  getScrollbar: =>
    distance = @tbody.width() - @content.width().top
    return (if distance > @scrollThreshold then distance else 0)

  getCellStats:(index, colData) =>
    if( @widthCache[index] ) then return @widthCache[index]
    largest = 0
    length = 0
    count = colData.length - 1
    for i in [0..count]
      width   = $($(colData[i]).find("span"), @tbody).outerWidth() + 15
      largest = width if width > largest
      length += width
    avg = Math.floor(length / count)
    @widthCache[index] =
      largest: largest
      average: avg
    return @widthCache[index]

  packTable: =>
    cellGroups = @tbody.find(".cell-group + .cell-group")
    colCount = @thead.find(".th").length
    colWidths = []
    newCols = []
    avgWidths = []
    packedReduction = 0
    cachedHeaders = []
    cachedColumns = []
    cellCount = $(@tbody.find(".tr")[0]).find(".td").length
    unless colCount is cellCount
      return false
    for i in [0..colCount-1]
      cachedHeaders[i] = @thead.find(".th:nth-child(" + (i + 1) + ")")
      cachedColumns[i] = @tbody.find(".tr .td:nth-child(" + (i + 1) + ")")
    for i in [0..colCount-1]
      stats = @getCellStats(i, cachedColumns[i])
      colWidths.push stats.largest
      avgWidths.push stats.average
    for i in [0..colCount-1]
      largest = colWidths[i]
      th = cachedHeaders[i].css("width", largest)
      td = cachedColumns[i].css("width", largest)
      newCols.push $(td[0]).outerWidth()
    sum = _.reduce(newCols, (a, b) -> a + b)
    selfWidth = @content.width()
    if sum >= selfWidth
      gaps = []
      distance = sum - selfWidth - 2
      _.each _.zip(colWidths, avgWidths), ((item) -> gaps.push item[0] - item[1])
      totalGap = _.reduce(gaps, (a, b) -> a + b)
      if totalGap is 0
        rolling = _.map(gaps, -> distance / colCount)
      else
        rolling = _.map(gaps, (item) -> Math.ceil distance * (item / totalGap))
        rollsum = _.reduce(rolling, (a, b) -> a + b)
      for i in [0..colCount-1]
        largest = colWidths[i]
        cachedHeaders[i].css "width", largest - rolling[i]
        cachedColumns[i].css "width", largest - rolling[i]
    else
      distance = selfWidth - sum
      bonus = Math.floor(distance / colCount)
      for i in [0..colCount-1]
        largest = colWidths[i]
        cachedHeaders[i].css "width", largest + bonus
        cachedColumns[i].css "width", largest + bonus
    lastCell = $(@tbody.find(".tr")[0]).find(".td:last-child")
    lastCellWidth = lastCell.outerWidth()
    lastCellEnd = lastCellWidth + lastCell.position().left
    distance = selfWidth - lastCellEnd
    unless distance is 0
      newWidth = lastCellWidth + distance
      cachedHeaders[colCount-1].css "width", newWidth
      cachedColumns[colCount-1].css "width", newWidth
