Collection = require "./collection"
application = require '../application'
#FramelistFrameView = require './framelistframe_view'

module.exports = class FilterCollection extends Collection
  _defaults:
    sortkey:false
    sortorder:-1
    sorttype:false
    skip:0
    limit:20
    query:''
  url:"/getFrames"
  mute:false
  clearOnFetch:true
  
  
  initialize: (models,params) =>
  	if params.mute?
  	  @mute = params.mute
    if params.clearOnFetch?
      @clearOnFetch = params.clearOnFetch
    @_boundCollections = []
    @_sortParams = _.clone @_defaults
    super()
    if params.bindFilter
      params.bindFilter.subCollection @
      @bindFilter = params.bindFilter
      @bindFilter
    else
      @bindFilter = false
    @baseUrl = @url
    @filters = []
    if !application.settings.ui_filters_framemetadata?
      application.settings.ui_filters_framemetadata = []
    if params.view
      @view = params.view
      i = 0
      for o in application.settings.ui_filters_framemetadata
        @filters.push @view.addSubview o.field_name, @loadFilter(o.format), '#filter_form', {params:o,collection:@,append:"filter_" + i}
        i+=1
    return @

  subCollection: (collection) =>
    @_boundCollections.push collection

  # Set sory param
  setParam:(key,val) =>
    @_sortParams[key] = val
    for o in @_boundCollections
      o.setParam key, val

  resetParam:(key) =>
    if @_defaults[key]?
      @_sortParams[key] = @_defaults[key]
      return @_sortParams[key]
    return false

  # Get sort param, or return val
  getParam:(key,val=false) =>
  	if @_sortParams[key]? and @_sortParams[key] != false
  	  return @_sortParams[key]
  	else
  	  return val

  loadFilter: (name) ->
    application.filters[name]
    
  getFilters: () =>
  	if @filters.length == 0 and @bindFilter
  	  return @bindFilter.getFilters()
  	return @filters
  
  sortList: (sorttype, sortkey, sortorder) =>
    for o in @getFilters()
      if o.options.params.field_name == sortkey
        @setParam('sortkey', sortkey)
        @setParam('sortorder', sortorder)
        @setParam('sorttype', sorttype)
    return
  
  alterFilters:() =>
    _json = []
    for o in @filters
      val = o.toJson()
      if val
        _json.push val
    @setParam 'query', _json
    return
  
  getSettings: (total=false, addParams) =>
    if total
      skip = 0
      limit = @getParam('skip')+@getParam('limit')
    else
      skip=@getParam('skip')
      limit=@getParam('limit')
    _json =
      skip:skip
      limit:limit
      query: @getParam 'query'
      sortkey: @getParam 'sortkey', 'capturetime_epoch'
      sortorder: @getParam 'sortorder'
      sortinfo:
        type: @getParam 'sorttype', ''
        name: @getParam 'sortkey', 'capturetime_epoch'
        order: @getParam 'sortorder'
    if addParams
      _json = _.extend _json, addParams
    return _json
    
  getUrl: (total=false, addParams, dataSet=false)=>
    #todo: map .error to params.error
    #if @bindFilter
    #  dataSet = @bindFilter.getSettings(total, addParams)
    if !dataSet
      dataSet = @getSettings(total, addParams)
    "/"+JSON.stringify dataSet

  preFetch:(callback)=>
    application.throbber.load()
    if !@clearOnFetch
      @_all = @models
    if typeof callback == 'function'
      return callback()
    return
  
  postFetch:(callback)=>
    application.throbber.clear()
    if !@clearOnFetch
      @add @_all, {silent: true}
      @_all = []
    if typeof callback == 'function'
      return callback()
    return

  fetch: (params={}) =>
    total = params.total || false
    _url = @baseUrl+@getUrl(total,params['params']||false)
    for o in @_boundCollections
      o.fetch()
    if !@mute
      @_all = @models
      @preFetch(params.before)
      params.success = (callback=params.success)=> @postFetch(callback)
      if @url != _url or params.force
        @url = _url
        super(params)
      else if params.success
        params.success()
  
  parse: (response) =>
  	@totalavail = response.total_frames
  	return response.frames