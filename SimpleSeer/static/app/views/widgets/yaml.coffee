SubView = require 'views/core/subview'
Template = require './templates/yaml'
Application = require 'application'
Collection = require 'collections/collection'
model_dashboard = require 'models/dashboard'
model_tabcontainer = require 'models/core/tab_container'
model_olap = require 'models/OLAP'
model_inspection = require 'models/inspection'
model_measurement = require 'models/measurement'
collection_dashboard = require 'collections/dashboards'
collection_tabcontainer = require 'collections/tab_container'
collection_olap = require 'collections/OLAPs'
collection_inspection = require 'collections/inspections'
collection_measurement = require 'collections/measurements'

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

  collections:
    Dashboard: new collection_dashboard()
    #TabContainer: new collection_tabcontainer()
    OLAP: new collection_olap()
    Inspection: new collection_inspection()
    Measurement: new collection_measurement()

  events: =>
    'click .button':'clickButton'

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

    @preFetch()

  preFetch: =>
    for key, collection of @collections
      collection.on 'reset', @render
      collection.fetch()

  firstTimeModal: =>
    Application.modal.show
      title: "Willkommen!"
      message: "<p class=\"center\">Hey there, just wanted to let you know this is your first time building this application :)</p>"
      submitText: 'Continue'
      cancelText: 'Cancel'
      throbber: false
      success: (options) => return

  editValue: (locArray) =>
    Application.modal.show
      title: "Edit Value"
      submitText: 'Save'
      cancelText: 'Cancel'
      form: [{id: "value", type: "text", label: "Value"}]
      throbber: false
      success: (options) => @updateValue(options, locArray)

  buildPath: (locArray, obj, parent) =>
    for i in locArray
      obj = obj[@buildPath(locArray, obj, parent)]
    return obj

  updateValue: (options, locArray) =>
    if locArray
      foo = @collections[locArray[0]].get(locArray[1])
      cln = _.clone locArray
      cln.splice(1, 1)
      target = @schema
      for key in cln.slice(0, -1)
        if !isNaN(key)
          target = target['item']
        else
          target = target[key]
      s = target[cln[cln.length-1]]
      if s
        if s.type == "Boolean"
          if options.value.toLowerCase() is "true"
            value = true
          else if options.value.toLowerCase() is "false"
            value = false
        if s.type == "String"
          value = String(options.value)
        if s.type == "Int"
          value = parseInt(options.value, 10)
        if value?
          target = foo.attributes
          for key in locArray.slice(2, -1)
            target = target[key]
          target[locArray[locArray.length-1]] = value
      foo.save(null, {success: => @collections[locArray[0]].fetch()})

  addValue: (locArray) =>
    Application.modal.show
      title: "Add Value"
      submitText: 'Save'
      cancelText: 'Cancel'
      form: [
        {id: "key", type: "text", label: "Key"},
        {id: "value", type: "text", label: "Value"}
      ]
      throbber: false
      success: (options) => @insertValue(options, locArray)

  insertValue: (options, locArray) =>
    cln = _.clone locArray
    cln.splice(1, 1)
    target = @schema
    for key in cln.slice(0, -1)
      if !isNaN(key)
        target = target['item']
      else
        target = target[key]
    s = target[cln[cln.length-1]]

    z = 0
    if s.type == 'Array' then z++

    if locArray
      foo = @collections[locArray[0]].get(locArray[1])
      tar = foo.attributes
      for key in locArray.slice(2, -1)
        tar = tar[key]

      if z
        obj = {}
        obj[options.key] = options.value
        tar[locArray[locArray.length-1]].push(obj)
      else
        if locArray.length == 2
          tar[options.key] = options.value
        else if locArray.length > 2
          tar[locArray[locArray.length-1]][options.key] = options.value

      foo.save(null, {success: => @collections[locArray[0]].fetch()})


  deleteValue:(locArray) =>
    foo = @collections[locArray[0]].get(locArray[1])
    if locArray.length == 2
      foo.destroy()
      @collections[locArray[0]].fetch()
    else if locArray.length > 2
      target = foo.attributes
      for key in locArray.slice(2, -1)
        target = target[key]
      if !isNaN(locArray[locArray.length - 1])
        target.splice(target.indexOf(target[locArray[locArray.length-1]]), 1)
      else
        delete(target[locArray[locArray.length-1]])
      foo.save(null, {success: => @collections[locArray[0]].fetch()})

  clickButton: (e) =>
    e.preventDefault();
    ctlocation = $(e.currentTarget).attr('location')
    tlocation = $(e.target).attr('location')
    action = $(e.target).attr('action')
    if ctlocation == tlocation
      locArray = tlocation.split("-")
      if action == "add"
        if locArray then @addValue(locArray)
      if action == "edit"
        if locArray then @editValue(locArray)
      if action == "delete"
        if locArray then @deleteValue(locArray)

  getValue: (location) =>
    loopy = @json
    _.each location, (i) =>
      if !loopy?
        loopy = @json[i]
      else
        loopy = loopy[i]
    return loopy

  getButtons: (key, loc) =>
    type = undefined
    a = 0
    b = 0
    c = 0
    ret = '<div class="buttons">'
    dest = loc + "-" + key
    if String(key) != 'id'

      locArray = dest.split("-")

      cln = _.clone locArray
      cln.splice(1, 1)
      target = @schema
      for key in cln.slice(0, -1)
        if !isNaN(key)
          target = target['item']
        else
          target = target[key]
      s = target[cln[cln.length-1]]

      console.log locArray, s

      if !isNaN(key)
        a++
        c++
      if s?
        if s.type == "Array" or s.type == "Object"
          if !s.required
            c++
        else if s.type == "String" or s.type == "Int"
          if !s.required
            b++
            c++

      ###if locArray.length == 3
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
          if !s?
            if @schema[locArray[0]][locArray[2]]['item'].extras
              b++
              c++
          else
            if s.type == 'Object' or s.type == 'Array'
              a++
            b++
            if !s.required
              c++###

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
      html += '<div class="item tree" location="' + loc + '">'
      html += '<strong>' + o.type + '</strong>'
      html += '<div class="buttons"><span class="button add" action="add" location="' + loc + '">A</span>' + '<span class="button delete" action="delete" location="' + loc + '">D</span></div>'
      html += @formatObject(o, loc)
      html += '</div>'
    return html

  getSchema: =>
    return @schema

  getData: =>
    ret = []
    for key, collection of @collections
      _.each collection.models, (i) =>
        ret.push(_.clone i.attributes)
        ret[ret.length-1].type = i.__proto__.constructor.name
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
      columnWidth: 520
      itemSelector: ".item"

  createObject: (type) =>
    collect = @collections[type]
    item = collect.create()
    collect.fetch()

  chosenInits: =>
    $('#new').chosen({
      no_results_text: "No results matched"
    }).change((event, ui) =>
      if (ui is undefined) then (ui = {selected: "_"})
      v = ui.selected
      @createObject(v)
    )
