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

  events: =>
    'click .confirmation span.answer': '_answer'

  _answer: (e) =>
    console.log e
    $(e.currentTarget).parents('.confirmation').find('input[type=radio]').prop('checked', true)
    $(e.currentTarget).parents('.confirmation').children('.answer').attr('data-selected', 'false')
    $(e.currentTarget).find('input[type=radio]').prop('checked', true)
    $(e.currentTarget).attr('data-selected', 'true')

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
    return features

  getRenderData: =>
    features: @_getFeatures()