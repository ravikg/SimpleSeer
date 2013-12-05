[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/turking")
  require("models/frame")
]

module.exports = class Turking extends SubView
  template: Template
  frames: []
  selected: null
  full: false
  frame: null
  key: 'id'
  featuretypes: ['badgefeature']
  featureoptions: {'badgefeature':['4x4', 'DURANGO', 'AWD']}

  events: =>
    'click .confirmation span.answer': '_answer'
    'click .add-feature': '_addFeature'
    'click .buttons .button': '_button'

  _toggleFeature: (e) =>
    text = $(e.target).attr('data-text')
    type = $(e.target).attr('data-type')
    @$(".feature[data-text=\"#{text}\"][data-type=\"#{type}\"]").find('.answer[data-selected=false]').click()

  _button: (e) =>
    dir = $(e.currentTarget).attr('data-value')
    if String(dir) is "next"
      if @options.parent._next?
        @options.parent._next(e)
    if String(dir) is "previous"
      if @options.parent._previous?
        @options.parent._previous(e)


  _answer: (e) =>
    $(e.currentTarget).parents('.confirmation').find('input[type=radio]').prop('checked', true)
    $(e.currentTarget).parents('.confirmation').children('.answer').attr('data-selected', 'false')
    $(e.currentTarget).find('input[type=radio]').prop('checked', true)
    $(e.currentTarget).attr('data-selected', 'true')

  _addFeature: (e) =>
    html = "<div class=\"feature new\">"
    html += "<select class=\"featuretype\">"
    for featuretype in @featuretypes
      html += "<option value=\"#{featuretype}\">#{featuretype}</option>"
    html += "</select>"
    html += "<span>not detected:</span>"
    html += "<select class=\"featureoptions\">"
    for featureoption in @featureoptions[featuretype]
      html += "<option value=\"#{featureoption}\">#{featureoption}</option>"
    html += "</select>"

    @$('.features').append(html)

  receive: (data) =>
    @frames = data
    frame = @_getFrame(@frames)
    if !@frame or @frame.get('id') != frame.get('id')
      @frame = frame
      console.log @frame
      @render()

  _getFrame: (frames, i=null) =>
    frame = null
    if i != null
      frame = frames[i]
    else if @selected
      for o,i in frames
        if o.get(@key) is String(@selected)
          frame = o
          break
    else
      if frames.length > 0
        frame = frames[0]

    if frame and frame.get?
      f = new Model({id:frame.get('id')})
      f.fetch({async:false})
      frame = f

    return frame

  select: (params) =>
    if params
      if params[@key]?
        @selected = params[@key]
        @frame = @_getFrame(@frames)
        @render()

  _getFeatures: =>
    features = []
    if @frame?.get?('features')
      for featuretype, list of @frame.get('features')
        for o,i in list
          text = if o.raw.featuredata.badge then o.raw.featuredata.badge else ''
          type = if o.raw.featuretype then o.raw.featuretype else ''
          i = i
          features.push({text:text, type:type, i:i})

    # Add empty validation for each feature type
    counts = {}
    for featuretype in @featuretypes
      if !counts[featuretype]
        counts[featuretype] = 0
      for feature in features
        if feature.type == featuretype
          counts[featuretype] += 1
      if counts[featuretype] is 0
        i = i + 1
        features.push({text:"NO", type:featuretype, i:i, empty: true})
    
    return features

  getRenderData: =>
    features: @_getFeatures()