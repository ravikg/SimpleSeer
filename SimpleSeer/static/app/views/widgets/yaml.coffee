SubView = require 'views/core/subview'
Template = require './templates/yaml'
Application = require 'application'
Collection = require 'collections/collection'
model_dashboard = require 'models/dashboard'
model_tabcontainer = require 'models/core/tab_container'
model_olap = require 'models/OLAP'
model_inspection = require 'models/inspection'
model_measurement = require 'models/measurement'

module.exports = class Yaml extends SubView
  template: Template
  depth: 0
  hover: undefined
  html: ''
  loc: undefined
  location: ''
  chosen: false
  json: []

  schema:
    Dashboard: model_dashboard.schema
    TabContainer: model_tabcontainer.schema
    OLAP: model_olap.schema
    Inspection: model_inspection.schema
    Measurement: model_measurement.schema
  t: 0

  events: =>
    'click .button':'clickButton'

  firstTimeModal: =>
    application.modal.show
      title: "Willkommen!"
      message: "Hey there, just wanted to let you know this is your first time building this application :)"
      okMessage: 'Continue'
      throbber: false
      success: (options) => return

  clickButton: (e) =>
    e.preventDefault();
    ctlocation = $(e.currentTarget).attr('location')
    tlocation = $(e.target).attr('location')
    action = $(e.target).attr('action')

    if ctlocation == tlocation
      locArray = tlocation.split("-")

      if action == "add"
        if locArray
          console.log "Adding item into", locArray

      if action == "edit"
        if locArray
          console.log "Editing item @ ", locArray

      if action == "delete"
        if locArray
          if locArray.length == 2
            if locArray[0] == 'Dashboard'
              foo = @dashboards.get(locArray[1])
              @dashboards.remove(foo)
              @render()
            if locArray[0] == 'TabContainer'
              foo = @tabcontainers.get(locArray[1])
              @tabcontainers.remove(foo)
              @render()
            if locArray[0] == 'OLAP'
              foo = @olaps.get(locArray[1])
              @olaps.remove(foo)
              @render()
            if locArray[0] == 'Inspection'
              foo = @inspections.get(locArray[1])
              @inspections.remove(foo)
              @render()
            if locArray[0] == 'Measurement'
              foo = @measurements.get(locArray[1])
              @measurements.remove(foo)
              @render()


  getValue: (location) =>
    loopy = @json
    _.each location, (i) =>
      if !loopy?
        loopy = @json[i]
      else
        loopy = loopy[i]
    return loopy

  initialize: =>

    $('body').on 'mouseover', '.tree', (o) ->
      c = $(o.target).attr('class')
      if c == "button" or c == "button add" or c == "button edit" or c == "button delete" or c == "buttons"
        $(o.target).children('.buttons').css('display', 'block')
      else
        $('body').find('.tree .buttons').css('display', 'none')
        if c == "tree" or c == "item tree"
          $(o.target).children('.buttons').css('display', 'block')
        else
          $(o.target).parent('.tree').children('.buttons').css('display', 'block')

    $('body').on 'mouseleave', '.tree', (o) ->
      c = $(o.target).attr('class')
      $('body').find('.tree .buttons').css('display', 'none')



    @dashboards = new Collection([{'id':'ABC123', 'name':'Human', 'type': 'Dashboard'}, {'id':'DEF456', 'name':'Readable', 'type': 'Dashboard'}, {'id': "5047bc49fb920a538c000001",'rowHeight': 100,'name': "Image View",'widgets': [{'name' : "hello", 'id':'aaa12312312'},{'name': "Frames",'canAlter': false,'model': 'null','view': "/widgets/yaml",'cols': 1,'id': "50d0b12c3ea38e249ed47b12"}],'locked': true,'cols': 1,'type': "Dashboard"}])
    @tabcontainers = new Collection([{'id':'GHI789', 'name':'Text', 'type':'TabContainer'}])
    @olaps = new Collection([])
    @inspections = new Collection([])
    @measurements = new Collection([])

    @render()

  getButtons: (key, loc) =>
    type = undefined
    a = 0
    b = 0
    c = 0
    ret = '<div class="buttons">'
    dest = loc + "-" + key
    if String(key) != 'id'

      locArray = dest.split("-")

      if locArray.length == 3
        s = @schema[locArray[0]][locArray[2]]
        if s.type == 'Object' or s.type == 'Array'
          a++
        else
          b++
        if !s.required
          c++

      if locArray.length == 4
        s1 = @schema[locArray[0]][locArray[2]]
        if s1.type == "Array"
          a++
          c++

      if locArray.length == 5
        s1 = @schema[locArray[0]][locArray[2]]
        if s1.type == "Array"
          s = @schema[locArray[0]][locArray[2]]['item'][locArray[4]]
          if s.type == 'Object' or s.type == 'Array'
            a++
          b++
          if !s.required
            c++
          
      if a
        ret += '<span class="button add" action="add" location="' + dest + '">A</span>'
      if b
        ret += '<span class="button edit" action="edit" location="' + dest + '">E</span>'
      if c
        ret += '<span class="button delete" action="delete" location="' + dest + '">D</span>'

    ret += '</div>'
    return ret

  formatObject: (obj, loc, inherit = false, key) =>
    if inherit and key
      loc += "-" + key
    ret = ''
    for key of obj
      if typeof obj[key] is "object"
        ret += '<div class="tree" location="' + loc + '-' + String(key) + '">'
        if !isNaN(key)
          type = "list-item"
        else
          type = typeof obj[key]
        ret += '<span class="key">' + String(key) + '</span>' + ' <small>(' + type + ')</small>'
        ret += @getButtons(key, loc)
        ret += @formatObject(obj[key], loc, true, String(key))
        ret += '</div>'
      else
        if String(key) == 'type'
          # Removed "type" and placed at main container
        else
          ret += '<div class="tree" location="' + loc + "-" + String(key) + '">'
          ret += '<span class="key">' + String(key) + ':</span><span class="value">' + String(obj[key]) + "</span>"
          ret += @getButtons(key, loc)
          ret += '</div>'
    ret

  formatHTML: (json) =>
    html = ''
    for key, o of json
      loc = o.type + "-" + o.id
      html += '<div class="item tree" collection="' + '" location="' + loc + '">'
      html += '<strong>' + o.type + '</strong>'
      html += '<div class="buttons"><span class="button add" action="add" location="' + loc + '">A</span>' + '<span class="button delete" action="delete" location="' + loc + '">D</span></div>'
      html += @formatObject(o, loc)
      html += '</div>'
    return html

  getSchema: =>
    return @schema

  getData: =>
    ret = []

    _.each @dashboards.models, (i) =>
      ret.push(i.attributes)
    _.each @tabcontainers.models, (i) =>
      ret.push(i.attributes)
    _.each @olaps.models, (i) =>
      ret.push(i.attributes)
    _.each @inspections.models, (i) =>
      ret.push(i.attributes)
    _.each @measurements.models, (i) =>
      ret.push(i.attributes)

    return ret

  render: =>
    @html = @formatHTML(@getData())
    super()

  getRenderData: =>
    'html': @html

  afterRender: =>
    @chosenInits()
    $container = $('#widget_grid .content')
    $container.masonry
      columnWidth: 530
      itemSelector: ".item"

  createObject: (type) =>
    if type == 'Dashboard'
      @dashboards.push({'id': 'A000000000000' + @t, 'name': 'Temporary-' + @t, 'type': 'Dashboard'})
    if type == 'TabContainer'
      @tabcontainers.push({'id': 'A000000000000' + @t, 'name': 'Temporary-' + @t, 'type': 'TabContainer'})
    if type == 'OLAP'
      @olaps.push({'id': 'A000000000000' + @t, 'name': 'Temporary-' + @t, 'type': 'OLAP'})
    if type == 'Inspection'
      @inspections.push({'id': 'A000000000000' + @t, 'name': 'Temporary-' + @t, 'type': 'Inspection'})
    if type == 'Measurement'
      @measurements.push({'id': 'A000000000000' + @t, 'name': 'Temporary-' + @t, 'type': 'Measurement'})
    @t++
    @render()

  chosenInits: =>
    $('#new').chosen({
      no_results_text: "No results matched"
    }).change((event, ui) =>
      if (ui is undefined) then (ui = {selected: "_"})
      v = ui.selected
      @createObject(v)
    )
