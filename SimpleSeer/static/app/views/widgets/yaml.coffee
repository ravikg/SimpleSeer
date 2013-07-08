SubView = require("views/core/subview")
Template = require("./templates/yaml")
Application = require("application")

module.exports = class Yaml extends SubView
  template: Template
  depth: 0
  hover: undefined
  html: ''
  location: ''
  chosen: false
  json: []

  collections: [
    require("collections/inspections"),
    require("collections/measurements"),
    require("collections/OLAPs"),
    #require("collections/tab_container"),
    require("collections/dashboards"),
    require("collections/chart")
  ]

  initialize: =>
    super()

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

    stuff = []
    console.log "Called"
    for collection in @collections
      e = new collection({bootstrap: false})
      e.fetch({success: @postFetch})
      stuff.push e
    @render()

  events: =>
    'click .button':'clickButton'

  postFetch:(collection) =>
    console.log collection.models

  saveJSON: (options) =>
    console.log "options", options

  showAddTypeModal: =>
    Application.modal.show
      title: "Add Object"
      message:'Hello There!'
      okMessage:'Save'
      cancelMessage:'Cancel'
      inputMessage:"A Value"
      throbber:false
      success:(options) => @saveJSON(options)

  clickButton: (e) =>
    e.preventDefault();
    ctd = $(e.currentTarget).attr('location')
    td = $(e.target).attr('location')
    action = $(e.target).attr('action')
    if ctd == td
      @location = []
      $(e.target).parents(".tree").each (o, i)=>
        @location.unshift($(i).attr('location'))
      value = @getValue(@location)

      if action == "add"
        if @location.length == 0
          @showAddTypeModal()
        else if @location
          console.log "Adding item into", @location

      if action == "edit"
        if @location
          console.log "Editing item @ ", @location

      if action == "delete"
        if @location
          console.log "Deleting item @ ", @location


  getValue: (location) =>
    loopy = @json
    _.each location, (i) =>
      if !loopy?
        loopy = @json[i]
      else
        loopy = loopy[i]
    return loopy

  formatObject: (obj, i = 0) =>
    ret = ''
    for key of obj
      if typeof obj[key] is "object"
        if i == 0
          ret += @formatObject(obj[key], 1)
        else
          i++
          ret += '<div class="tree" location="' + String(key) + '">'
          if !isNaN(key)
            type = "list-item"
          else
            type = typeof obj[key]
          ret += '<span class="key">' + String(key) + '</span>' + ' <small>(' + type + ')</small>'
          ret += '<div class="buttons"><span class="button add" action="add" location="' + String(key) + '">A</span>' + '<span class="button edit" action="edit" location="' + String(key) + '">E</span>' + '<span class="button delete" action="delete" location="' + String(key) + '">D</span></div>'
          ret += @formatObject(obj[key], i)
          ret += '</div>'
      else
        if String(key) == 'type'
          # Removed "type" and placed at main container
        else
          ret += '<div class="tree" location="' + String(key) + '">'
          ret += '<span class="key">' + String(key) + ':</span><span class="value">' + String(obj[key]) + "</span>"
          if String(key) != 'id'
            ret += '<div class="buttons">' + '<span class="button edit" action="edit" location="' + String(key) + '">E</span>' + '<span class="button delete" action="delete" location="' + String(key) + '">D</span></div>'
          ret += '</div>'
    ret

  formatHTML: (json) =>
    html = ''
    for key, o of json
      html += '<div class="item tree" location="' + key + '">'
      html += '<strong>' + o.type + '</strong>'
      html += '<div class="buttons"><span class="button add" action="add" location="' + String(key) + '">A</span>' + '<span class="button edit" action="edit" location="' + String(key) + '">E</span>' + '<span class="button delete" action="delete" location="' + String(key) + '">D</span></div>'
      html += @formatObject(o)
      html += '</div>'
    return html

  render: =>
    @html = @formatHTML(@json)
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
    # @TODO: Faux data object addition, would actually ping database, create new object
    # and return the actual id and model of the object.
    @json.unshift
      obj:
        id: "511417bf3ea38e38957456d0"
      type: type

    @render()

  chosenInits: =>
    # New Object
    $('#new').chosen({
      no_results_text: "No results matched"
    }).change((event, ui) =>
      if (ui is undefined) then (ui = {selected: "_"})
      v = ui.selected
      @createObject(v)
    )
