SubView = require 'views/core/subview'
application = require 'application'
template = require './templates/table'
rowTemplate = require './templates/row'
Collection = require "collections/table"
Frame = require "models/frame"

# Standardized Table View

module.exports = class Table extends SubView
  template:template
  rowTemplate:rowTemplate
  direction:-1
  insertDirection: -1
  renderComplete:false
  sortKey:'capturetime'
  sortDirection:'desc'
  cof:false

  events :=>
    "click th" : "thSort"

  initialize: =>
    @rows = []
    super()
    if !@options.page?
      @options.page = "inf"
    else
      @cof = true

    # Hardcoded columns names
    # @TODO - Move this into the database
    @tableCols = [
      key: "id"
      title: "ID"
    ,
      key: "camera"
      title: "Camera"
    ,
      key: "capturetime"
      title: "Capture Times"
    ]

    # Get the collection
    @collection = new Collection([],{model:Frame,clearOnFetch:@cof})
    if @sortKey == 'capturetime'
      @collection.setParam 'sortkey', 'capturetime_epoch'
    else
      @collection.setParam 'sortkey', @sortKey
    @collection.setParam 'sortorder', @direction
    @collection.fetch
      success:@updateData

    if @options.page == "inf"
      @on "page", @infinitePage
    else
      # @TODO: Initialize the html pagination

    return

  # Render the empty table with given @tableCols
  getRenderData: =>
    cols:@tableCols
    rows:@rows
    pageButtons:@options.page == "page"

  # Render the row
  renderRow:(row) =>
    values = []
    $.each @tableCols, (k, v) ->
      r = {'class' : v.key, 'value' : row[v.key]}
      values.push r

    return {id:row.id, values:values}

  # Insert a new row
  insertRow: (row, insertDirection = 1) =>
    if insertDirection == -1
      @rows.unshift @rowTemplate @renderRow(row)
    else
      @rows.push @rowTemplate @renderRow(row)
    return "Insert row"

  # Initialize persistant headers
  initializeHeaders: =>
    sh = @$el.find('thead tr.sh')
    offset = sh.offset()

    ph = @$el.find('thead tr.ph')
    ph.css('width', sh.css('width'))
    
    # @TODO: Change this so it always references @$el
    $('#slides').scroll(@updateHeaders)
    
  thSort:(e) =>
    # Click events for sorting
    key = $(e.target).attr('class')
    direction = $(e.target).attr('direction')
    unless direction
      direction = 'desc'

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

    @collection.fetch
      filtered:true
      success: @updateData

  updateHeaders: =>
    sh = @$el.find('thead tr.sh')
    ph = @$el.find('thead tr.ph')

    # @TODO: Change this so it always references @$el
    if @dashboard? and @dashboard.locked and @dashboard.subviews.length == 1
      scrollTop = @$el.scrollTop()
    else 
      scrollTop = $('#slides').scrollTop()

    offset = sh.offset()
    
    $.each @tableCols, (k, v) ->
      th = 'th.' + v.key
      width = sh.find(th).width() + 10
      ph.find(th).css('width', width)

    if (scrollTop > offset.top)
      ph.css("visibility", "visible")
    else
      ph.css("visibility", "hidden")

  # Completed collection fetch, render the table content
  updateData: =>
    # Iterate through the collection list
    @rows = []
    _.each @collection.models, (model) =>
      @insertRow(model.attributes, @insertDirection)

    # Initialize persistant headers
    @initializeHeaders()

    @render()
    return

  # Paginate
  paginate: =>
    # @TODO: Change this so it always references @$el
    $('#slides').infiniteScroll({onPage: => @nextPage})

  appendData: =>
    @rows = []
    _.each @collection.models, (model) =>
      @insertRow(model.attributes, @insertDirection)

    @render()

  infinitePage: =>
    if @collection.lastavail == 20 
      @collection.setParam('skip', (@collection.getParam('skip') + @collection._defaults.limit))
      @collection.fetch success:@appendData
    return

  afterRender: =>
    # Add sort css
    @$el.find('th.' + @sortKey).attr('direction', @sortDirection).append('<span class="dir ' + @sortDirection + '"></span>')
    return

  # Render!
  render: =>
    t = super()
    return t