Collection = require "./collection"
OLAP = require "../models/OLAP"
ChartView = require '../views/chart'
application = require '../application'
charts = require '../views/charts/init'


module.exports = class OLAPs extends Collection
  url: "/api/chart"
  model: OLAP
  paused: false
  timeframe:300
  
  initialize: (args={}) =>
    # Bind view to collection so we know where our widgets live
    if args.view?
      @view = args.view
    super(args)

  fetch: (args={}) =>
    # Create default success action if none supplied to fetch
    if !args.success?
      _.extend args,
        success: @onSuccess
    super(args)
  
  # Default success action
  onSuccess: (obj, rawJson) =>
    # Sort charts by render order
    # To be deprecated with grid layout
    rawJson.sort (a,b) ->
      (a.renderorder || 100) - (b.renderorder || 101)
    for rawObj in rawJson
      # Get model
      model = @get rawObj.id
      ################
      # TODO: check if chart has chartid
      #       if chartid, get chart and add series
      #       pass in chart type so highcharts can support line pie stack
      #       http://jsfiddle.net/gh/get/jquery/1.7.2/highslide-software/highcharts.com/tree/master/samples/highcharts/demo/combo/
      if !model.view
        if charts[rawObj.style]
          _id = rawObj.name
          vi = @view.addSubview _id, charts[rawObj.style], '#charts', {append:_id,id:rawObj.id,model:model}
          vi.render()
        else
          console.error rawObj.style + ' is not a valid chart type'
    return

###
  previewImage: (fId) =>
    if application.charts.paused
      @.changeFrameImage fId

  unclickPoint: (fId) =>
    for m in @.models
      if m.view.chart._c.get
        p = m.view.chart._c.get fId
        if p && p.marker && p.marker.radius > 2
          p.update({ marker: {}},true)
    return false

  changeFrameImage: (fId) =>
    fDom = $('#frame img')
    if !fDom.attr('live')
      fDom.attr('live',fDom.attr('src'))
    fDom.attr('src','/grid/imgfile/'+fId)

  pause: (fId) =>
    @.paused = true
    control = $ "#realtimecontrol"
    control.html "History"
    control.attr "title", "Click to enter live mode"
    if !fId
      fId = @lastframe
    @.changeFrameImage fId
    if application.socket
      for obj in @.models
        application.socket.emit 'unsubscribe', 'OLAP/'+obj.attributes.name+'/'
    #application.alert('<a href="#">Pause</a>','error')

  unpause: =>
    @.paused = false
    control = $ "#realtimecontrol"
    control.html "Live"
    control.attr "title", "Click to pause"
    for obj in @.models
      tf = Math.round((new Date()).getTime() / 1000) - application.charts.timeframe
      obj.view.update parseInt(tf)
      if application.socket
        application.socket.emit 'subscribe', 'OLAP/'+obj.attributes.name+'/'
    $('.alert_error').remove()
    fDom = $('#frame img')
    fDom.attr('src',fDom.attr('live'))
    $('#preview').html ''

  callFrame: (e) =>
    if !@.paused
      application.homeView.realtimeControl()
      #@.pause(e.point.config.id)
      
  addFrame: (id) =>
    if !@.paused
      application.homeView.realtimeControl()
    @.pause id
    if application.framesets.models[0]
      application.framesets.models[0].addFrame(id)
    #$('#preview').append '<img style="width:100px" id="image_'+e.target.id+'" src="/grid/imgfile/'+e.target.id+'">'
  
  removeFrame: (id) =>
    $('#image_'+id).remove()
###
