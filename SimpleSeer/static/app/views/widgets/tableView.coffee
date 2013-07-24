SubView = require 'views/core/subview'
application = require 'application'
template = require './templates/tableView'

# TableView is a wrapper for the jQuery UI Tablesorter
# wigdet. Allows you to pass in data and draw it
# programmatically.

module.exports = class tableView extends SubView
  # Define some working variables.
  template:template

  _init: =>
    @tableData = []
    @columnOrder = []
    @emptyCell = ""
    @widgets = []
    @doNotSort = []
    @widgetData = []
    return

  # Event handlers for the export buttons.
  events:
    'click #excel_button':'export'
    'click #csv_button':'export'

  # Localizes the scope of the widget settings.
  initialize: =>
    @_init()
    if @options.doNotSort?
      @doNotSort = @options.doNotSort
    if @options.widgetData?
      @widgetData = @options.widgetData
    #@initPlugins()
    
    @widgets = @options.widgets || []
    @widgets.push "zebra"
    @emptyCell = @options.emptyCell if @options.emptyCell
    @columnOrder = @options.columnOrder if @options.columnOrder
    @downloadLinks = @options.downloadLinks
    super

  # Clears the table.
  empty: =>
    @tableData = []

  # Add a row into the table.
  addRow: (row) =>
    newRow = {}
    for i,o of row
      if typeof o == 'object'
        text = o.text
        style = o.style 
        tooltip = o.tooltip
        link = o.link
      else
        text = o
        style = false
        link = false
        tooltop = ""
      if @isEmpty text
        text = @emptyCell
      newRow[i] = {text:text}
      if style
        newRow[i].style = style
      if link
        newRow[i].link = link
      if tooltip
        newRow[i].tooltip = tooltip
    @tableData.push newRow
    
  # Pushes the table data into a hidden
  # input form value.
  export: (ui) =>
    @$el.find('input[name="format"]').attr('value',ui.target.value)
    true

  # [NOT IMPLEMENTED]
  #  56%
  #  percent = if ends with %
  #  int = if is int
  #  date = if typeof date (if !moment, switch to moment) 
  getType: (val) =>
    
  # Helper function to return falsy table
  # data.
  isEmpty: (val) =>
    val == false || val == ''

  # Renders the table. Will replace the date
  # header with the current timezone.
  afterRender: =>
    super()
    if @options.downloadLinks
      @$el.find('.download-links').show()
    else
      @$el.find('.download-links').hide()   
    l = @$el.find('thead :visible th')
    for dn in l
      if dn.innerHTML == "Capture Time"
        dn.innerHTML += " " + new Date().toString().match(/\(.*\)/g)
        
    js = @rows
    js.unshift @header
    js = ((r.text for r in row) for row in @rows)
    $("input[name=rawdata]").attr('value',(JSON.stringify js).replace RegExp(@emptyCell,'g'), '' )
    @$el.find('.tablesorter').tablesorter
      widgets: @widgets,
      headers:@_headerSettings()
    @showEditFields()
    return

  _headerSettings:=>
    if @widgetData.editable?
      for i,n in @widgetData.editable
        if i not in @doNotSort
          @doNotSort.push i
    headers = {}
    for i,n in @header
      if i in @doNotSort
        headers[n] = {sorter:false}
    return headers
    

  # Builds a two dimensional array for the
  # template to render out. Will fill in
  # missing cells with a blank representation.
  getRenderData: =>
    retHeader = []
    retRow = []
    rr = []
    
    # Populate initial column order.
    for col in @columnOrder
      retHeader.push col
      
    # Populate row data.
    for row in @tableData
      _r = []
      while _r.length < retHeader.length
        _r.push @emptyCell
      for col, rowItem of row
        i = retHeader.indexOf(col)
        if i == -1
          retHeader.push col
          i = retHeader.indexOf(col)
        _r[i] = rowItem
      rr.push _r
      
    # Fill each row with empty cells if needed.
    for a in rr
      while a.length < retHeader.length
        a.push @emptyCell
      retRow.push a

    @header = retHeader
    @rows = retRow
    return {header:retHeader,row:retRow}

  # override for chage events
  changeCell:(item)=>
    obj = $(item.target)
    #console.log obj.attr('editFieldIndex')
    #console.log obj.val()

  showEditFields: =>
    table = @$el.find('.tablesorter')
    if @widgetData.editable
      cols = {}
      for i,n in $("thead th",table)
        cols[i.innerHTML] = n
      for i in @widgetData.editable
        ind = (cols[i])+1
        $('tr td:nth-child('+ind+')',table).each (index) ->
          _lab = ['max','min']
          if $(@).find('input').length <=0
            arr = @innerHTML.split(',')
            str = ""
            for o, _i in arr
              args=
                editFieldIndex:i+"."+index+"."+_i
                placeholder:_lab[_i]
                type:"text"
                value:o.trim()
              # TODO: i dont like this outerHTML stuff
              foo = $('<input/>',args)
              str += foo[0].outerHTML
            @innerHTML = str
            return
      ind = (cols[@widgetData.editableKey])+1
      _key = @widgetData.editableKey
      $('tr td:nth-child('+ind+')',table).each (index) ->
        ele = $(@)
        ele.attr('editFieldKey', _key+"."+index+".0")
     
    $('[editFieldIndex]',table).on("change", @changeCell)
    return
  
