SubView = require 'views/core/subview'
template = require './templates/yaml'
application = require 'application'

module.exports = class Yaml extends SubView
  template: template
  depth: 0
  hover: undefined
  html: ''
  data: ''
  json: [
    obj:
      id: "511417bf3ea38e38957456d0"
      tabs: [
        model_id: "5047bc49fb920a538c000000"
        selected: 'true'
        name: "Image View"
        icon: "/img/imageview.png"
        view: "dashboard"
      ,
        model_id: "5047bc49fb920a538c000001"
        selected: false
        name: "Admin"
        icon: "/img/imageview.png"
        view: "dashboard"
      ]
      name: "Stats"
      context: "stats"
      navbar: "left-main"
      path: "stats"

    type: "TabContainer"
  ,
    obj:
      rowHeight: 100
      name: "Image View"
      widgets: [
        name: "Frames"
        canAlter: false
        model: 'null'
        view: "/widgets/yaml"
        cols: 1
        id: "50d0b12c3ea38e249ed47b12"
      ]
      locked: true
      cols: 1
      id: "5047bc49fb920a538c000001"

    type: "Dashboard"
  ,
    obj:
      id: "5089a6d31d41c855e4628fb1"
      olapFilter:
        criteria: [
          type: "frame"
          name: "capturetime_epoch"
          exists: 1
        ]
        logic: "and"

      name: "All"

    type: "OLAP"
  ]

  events: =>
    'click .button':'clickButton'

  clickButton: (e) =>
    e.preventDefault();
    ctd = $(e.currentTarget).attr('data')
    td = $(e.target).attr('data')
    action = $(e.target).attr('action')
    if ctd == td
      @data = []
      $(e.target).parents(".tree").each (o, i)=>
        @data.unshift($(i).attr('data'))
      value = @getValue(@data)

      if action == "add"
        if ctd == "type"
          console.log "Adding new object"
          @json.push(@addition)
          @render()
        else if @data
          console.log "Adding item into", @data

      if action == "edit"
        if @data
          console.log "Editing item @ ", @data

      if action == "delete"
        if @data
          console.log "Deleting item @ ", @data


  getValue: (data) =>
    loopy = @json
    _.each data, (i) =>
      if !loopy?
        loopy = @json[i]
      else
        loopy = loopy[i]
    return loopy


  initialize: =>
    super()

    $('body').on 'mouseover', '.tree', (o) ->
      c = $(o.target).attr('class')
      if c == "button" or c == "button add" or c == "button edit" or c == "button delete" or c == "buttons"
        $(o.target).children('.buttons').css('display', 'block')
      else
        $('body').find('.tree .buttons').css('display', 'none')
        $(o.target).children('.buttons').css('display', 'block')

    $('body').on 'mouseleave', '.tree', (o) ->
      c = $(o.target).attr('class')
      $('body').find('.tree .buttons').css('display', 'none')

    @render()


  formatObject: (obj, i = 0) =>
    ret = ''
    for key of obj
      if typeof obj[key] is "object"
        if i == 0
          ret += @formatObject(obj[key], 1)
        else
          i++
          ret += '<div class="tree" data="' + String(key) + '">'
          ret += '<span class="key">' + String(key) + '</span>' + ' <small>(' + typeof obj[key] + ')</small>'
          ret += '<div class="buttons"><span class="button add" action="add" data="' + String(key) + '">A</span>' + '<span class="button edit" action="edit" data="' + String(key) + '">E</span>' + '<span class="button delete" action="delete" data="' + String(key) + '">D</span></div>'
          ret += @formatObject(obj[key], i)
          ret += '</div>'
      else
        if String(key) == 'type'
          # Removed "type" and placed at main container
        else
          ret += '<div class="tree" data="' + String(key) + '">'
          ret += '<span class="key">' + String(key) + ':</span><span class="value">' + String(obj[key]) + "</span>"
          ret += '<div class="buttons">' + '<span class="button edit" action="edit" data="' + String(key) + '">E</span>' + '<span class="button delete" action="delete" data="' + String(key) + '">D</span></div>'
          ret += '</div>'
    ret

  formatHTML: (json) =>
    html = ''
    for key, o of json
      html += '<div class="item tree" data="' + key + '">'
      html += '<strong>' + o.type + '</strong>'
      html += '<div class="buttons"><span class="button add" action="add" data="' + String(key) + '">A</span>' + '<span class="button edit" action="edit" data="' + String(key) + '">E</span>' + '<span class="button delete" action="delete" data="' + String(key) + '">D</span></div>'
      html += @formatObject(o)
      html += '</div>'
    return html

  render: =>
    @html = @formatHTML(@json)
    super()

  getRenderData: =>
    'html': @html