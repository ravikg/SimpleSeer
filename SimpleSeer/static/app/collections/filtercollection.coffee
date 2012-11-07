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
    query:[]
  url:"/getFrames"
  mute:false
  clearOnFetch:true
  
  
  initialize: (models,params) =>
  	# Create callback stack for functions to be called before and after a fetch
  	@callbackStack = {}
  	@callbackStack['post'] = []
  	@callbackStack['pre'] = []

    # The mute param: use if filter collection is a parent and does not contain data
  	if params.mute?
  	  @mute = params.mute
  	
  	# The clearOnFetch param:
  	# true: (default) clears collection on fetch.
  	# false: retains data in collection (for pagination)
    if params.clearOnFetch?
      @clearOnFetch = params.clearOnFetch

    # init bound collections in private space
    @_boundCollections = []

    # init sort params in private space
    @_sortParams = _.clone @_defaults

    super()
    
    # bindFilter:
    #   an instance of FilterCollection that when changed, bubbles the filter
    #   up through all bound filters.
    #   example: Creating a FilterCollection with mute on, then creating
    #            5 other FilterCollections bound to the initial instance.
    #            when you change the initial FilterCollection, all others
    #            refresh with filter settings
    if params.bindFilter
      params.bindFilter.subCollection @
      @bindFilter = params.bindFilter
      @bindFilter
      @_sortParams = @bindFilter.getSettings()
    else
      @bindFilter = false
    
    # Set baseUrl off of default url.  url is changed, baseUrl remains root url
    @baseUrl = @url
    
    # Load filter widgets
    # TODO: make these collections
    @filters = []
    if !application.settings.ui_filters_framemetadata?
      application.settings.ui_filters_framemetadata = []

    # Render filter widgets
    if params.view
      @view = params.view
      i = 0
      for o in application.settings.ui_filters_framemetadata
        @filters.push @view.addSubview o.type+"_"+o.field_name, @loadFilter(o.format), '#filter_form', {params:o,collection:@,append:"filter_" + i}
        i+=1
    return @

  # Add sub collection
  subCollection: (collection) =>
    @_boundCollections.push collection

  # Set sort param.  Bubble up through bound FiltersCollections
  setParam: (key,val) =>
    @_sortParams[key] = val
    for o in @_boundCollections
      o.setParam key, val

  # Reset sort param.  Do not Bubble up through bound FiltersCollections
  resetParam: (key) =>
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

  # Get filter library from application
  loadFilter: (name) ->
    application.filters[name]
  
  # Get bound filters and mix-in bound FilterCollection filters
  getFilters: () =>
  	_filters = @filters
  	if @bindFilter
  	  _filters = _filters.concat @bindFilter.getFilters()
  	return _filters

  # Sort collection
  sortList: (sorttype, sortkey, sortorder) =>
    for o in @getFilters()
      if o.options.params.field_name == sortkey
        @setParam('sortkey', sortkey)
        @setParam('sortorder', sortorder)
        @setParam('sorttype', sorttype)
    return
  
  # Sync filters
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

  preFetch:()=>
    application.modal.show()
    if !@clearOnFetch
      @_all = @models
    for o in @callbackStack['pre']
      if typeof o == 'function'
        o()
    @callbackStack['pre'] = []
    return
  
  postFetch:()=>
    application.modal.onSuccess()
    if !@clearOnFetch
      @add @_all, {silent: true}
      @_all = []
    for o in @callbackStack['post']
      if typeof o == 'function'
        o()
    return

  globalRefresh:=>
    @fetch({force:true})

  fetch: (params={}) =>
    total = params.total || false
    _url = @baseUrl+@getUrl(total,params['params']||false)
    for o in @_boundCollections
      o.fetch(params)
    if !@mute
      @_all = @models
      @callbackStack['pre'].push params.before
      @preFetch()
      @callbackStack['post'].push params.success
      params.success = @postFetch
      if @url != _url or params.force
        @url = _url
        super(params)
      else if params.success
        params.success()
  
  parse: (response) =>
  	@totalavail = response.total_frames
  	return response.frames