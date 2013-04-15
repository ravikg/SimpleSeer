SubView = require 'views/core/subview'
application = require 'application'
template = require './templates/table'
rowTemplate = require './templates/row'
Collection = require "collections/table"
#Frame = require "models/frame"
#Measurement = require "models/measurement"

# Standardized Table View
# @TODO: Fix the sorting issue -- collection set array is in reverse order

module.exports = class Table extends SubView
  template:template
  rowTemplate:rowTemplate
  direction:-1
  insertDirection: -1
  renderComplete:false
  sortKey:'id'
  sortDirection:'desc'
  cof:false
  editable:true
  editableList:{}
  header:undefined
  limit:50
  headersInit:false
  tbody: {}
  thead: {}
  content: {}
  scrollThreshold: 4
  widthCache: {}

  events :=>
    "click .th" : "sortByColumn"
    "change .tbody input" : "changeCell"

  onPage: =>
    @infinitePage()

  getOptions: =>
    # Setting up our initial conditions, options, variables, columns etc

    if @options.sortKey? and @options.sortKey
      @sortKey = @options.sortKey

    if @options.sortDirection? and @options.sortDirection
      @direction = @options.sortDirection
      if @direction == 1
        @sortDirection = 'asc'
      else
        @sortDirection = 'desc'

    if @options.editable? and @options.editable
      @editable = @options.editable

    if !@options.tableCols?
      @tableCols = [
        key: "id"
        title: "ID"
      ]
    else
      @tableCols = @options.tableCols

    # Get the collection
    if @options.collection_model
      @_collection = require "collections/" + @options.collection_model + "s"
      @_model = require "models/" + @options.collection_model
      @_url = "api/"+@options.collection_model
    else
      @_collection = require "collections/table"
      @_model = require "models/frame"
      @_url = "api/frame"

    # Pick how we want to paginate this bad boy
    #if @options.page == "inf"
    #  @on "page", @infinitePage
    #else
    #  @on "page", @infinitePage
    # @TODO: Initialize the html pagination

  getCollection: =>
    @collection = new @_collection([],{model:@_model,clearOnFetch:@cof,url:@_url})

    if !@options.collection_model
      if @sortKey == 'capturetime'
        @collection.setParam 'sortkey', 'capturetime_epoch'
      else
        @collection.setParam 'sortkey', @sortKey
      @collection.setParam 'sortorder', @direction

    @collection.fetch
      success:@updateData

  initialize: =>
    super()
    @rows = []
    @getOptions()
    @getCollection()
    return

  # Render the empty table with given @tableCols
  getRenderData: =>
    header:@header
    cols:@tableCols
    rows:@rows
    pageButtons:@options.page == "page"

  isEditable: (cols, key) =>
    edit = 0
    $.each cols, (k, v) ->
      if v.key == key
        if v.editable? and v.editable
          edit++
    if edit
      return true
    else
      return false

  subCols: (key) =>
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

  # Render the cell
  renderCell: (raw, key) =>
    value =
      html: ""
      raw: raw
    # Special cases go here? Human readable, etc.
    parentKey = key
    v = raw

    # Process the cell for an editable field
    if @editable
      if @isEditable(@tableCols, key)
        subcols = @subCols(key)
        if subcols
          html = '<div class="subCols">'
          $.each subcols, (k, v) =>
            key = v.key
            path = key.split('-')
            val = ''
            if v? and v and v[path[2]]? and v[path[2]]
              val = v[path[2]]
            placeholder = v.title
            if @isEditable(subcols, key)
              args = {
                placeholder: placeholder
                type: 'text'
                name: parentKey + '-' + path[2]
                v: val
                class: parentKey + '-' + path[2]
              }
              html += '<div class="subCol">'
              html += "<input "
              $.each args, (k, v) =>
                html += k + '="' + v + '" '
              html += "/></div>"
            else
              html += '<div class="' + parentKey + '.' + key + '">' + val + '</div>';

          html += '</div>';
          v = html
        else
          # @TODO: Pull nullval into scope here
          args = {
            placeholder: v
            type: 'text'
            v: v
            class: key
          }
          html = "<input "
          $.each args, (k, v) =>
            html += k + '="' + v + '" '
          html += "/>"
          v = html

    value['html'] = if v then v else raw
    return value

  changeCell: (e) =>
    ###
    console.log "Saved cell"
    '''target = $(e.target)
    id = target.parents('tr').attr('id')
    key = target.attr('class')
    value = target.val();
    if id and key and value
      frame = @collection.get(id)
      o = key.split('-')
      if o.length > 1
        p = frame.get(o[0])
        if !p[o[1]]?
          p[o[1]] = {}
        p[o[1]][o[2]] = value
        @saveCell(frame, p, p[0])
      else
        obj = {}
        obj[key] = value
        @saveCell(frame, obj)'''
    ###

  saveCell: (frame, obj, key = '') =>
    frame.save if key then {key: obj} else obj

  # Render the row
  renderRow:(row) =>
    values = []
    $.each @tableCols, (k, v) =>
      path = v.key.split('-')
      if path.length > 1
        r = row.get(path[0])
        key = v.key
        val = r[path[1]]
      else
        key = v.key
        val = row.get(path[0])

      value = @renderCell(val, key)
      r = {'class' : v.key, 'value' : value}
      values.push r

    return {id:row.id, values:values}

  # Insert a new row
  insertRow: (row, insertDirection = 1) =>
    if insertDirection is -1
      @rows.unshift @rowTemplate @renderRow(row)
    else
      @rows.push @rowTemplate @renderRow(row)
    return "Insert row"

  # Initialize persistant headers
  initializeHeaders: =>
    sh = @$el.find('.thead .tr.sh')
    offset = sh.offset()

    ph = @$el.find('.thead .tr.ph')
    ph.css('width', sh.css('width'))

    # @TODO: Change this so it always references @$el
    $('#slides').scroll(@updateHeaders)

  sortByColumn:(e, set) =>
    # Click events for sorting

    key = $(e.currentTarget).data('key')
    direction = $(e.currentTarget).attr('direction')

    unless direction
      direction = 'desc'

    if !set
      if key == "capturetime"
        @collection.setParam 'sortkey', 'capturetime_epoch'
      else
        @collection.setParam 'sortkey', key

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
      success: @updateData

  formatData: (data) =>
    return data

  # Completed collection fetch, render the table content
  updateData: =>
    @$el.find('.table .tbody').html('')

    # Iterate through the collection list
    data = @formatData(@collection.models)

    @rows = []
    _.each data, (model) =>
      @insertRow(model, @insertDirection)

    # Initialize persistant headers
    if !@headersInit
      @initializeHeaders()
      @headersInit = true

    @render()
    return

  # Paginate
  paginate: =>
    # @TODO: Change this so it always references @$el
    @$el.infiniteScroll({onPage: => @infinitePage})

  #appendData: =>
  #  console.log "appenddata"
  #  @rows = []
  #  _.each @collection.models, (model) =>
  #    @insertRow(model, @insertDirection)
  #  @render()

  infinitePage: =>
    if @collection.lastavail >= @limit
      @collection.setParam('skip', (@collection.getParam('skip') + @limit))
      @collection.fetch()
    return

  afterRender: =>
    #@$el.infiniteScroll({ onPage: => @infinitePage })
    $(window).resize(@packTable)
    @$el.find(".th[data-key=#{@sortKey}]")
      .removeClass("sort-asc sort-desc").addClass("sort-#{@sortDirection}")
      .attr('direction', @sortDirection)
    @tbody = @$(".tbody").scroll(@pollShadow)
    @thead = @$(".thead")
    @content = @tbody.find(".tscroll")
    @packTable()

  reflow: =>
    @packTable()

  pollShadow: =>
    @thead.removeClass("shadow")
    @thead.addClass("shadow") if @tbody.scrollTop() > 0

  getScrollbar: =>
    distance = @tbody.width() - @content.width()
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
      message  = "Warning: Column count in headers (#{colCount}) "
      message += "different than in cells (#{cellCount}). "
      message += "Cannot pack table."
      console.log message
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

  render: =>
    t = super()
    return t
