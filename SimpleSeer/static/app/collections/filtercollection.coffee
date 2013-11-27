Collection = require "collections/collection"

module.exports = class FilterCollection extends Collection
# \_defaults acts as the default values for the `FilterCollection`.  They are copied in to the `_sortParams` and manipulated from there.
# The `_sortParams` values are to be set or get using the `getParam` or `setParam` functions.  You can also reset them at any time with the `resetParam` function
#
# - __sortkey: (*string*)__ the key of the column to sort by (example: `"capturetime_epoch"` or `"results.numeric"`)
# - __sorttype: (*string*)__ matches measurement name to search by (example `"motion"` or `"blob"`)
# - __sortorder: (*int*)__ valid values are -1 or 1. -1 sets the sort to desc, 1 sorts to asc
# - __skip: (*int*)__ number of records to skip (used for pagination)
# - __limit: (*int*)__ number of records to return (used for limiting result sets and pagination)
# - __query: (*obj*)__ query params for mongoengine.  Typically only used by the filters, but here are some examples:
#   - *Simple Query:* `{"logic":"and","criteria":[{"type":"left","eq":1,"name":"results.state"}]}`
#   - *Logical Query:* `{"logic":"and","criteria":[{"type":"left","eq":1,"name":"results.state","logic":"and","criteria":[{"type":"left","eq":1,"name":"results.state"}]}]}`
# - __groupby: (*string*)__ the column which you want to group your data by (example: `"capturetime_epoch"` or `"results.numeric"`)
# - __groupfns: (*string*)__ the function you want to group your data by
#   - *Functions:* `list`, `first`, `last`, `max`, `min`, `avg`, `sum`
  _defaults:
    sortkey:false
    sorttype:false
    sortorder:-1
    skip:0
    limit:20
    query:{}
    groupby:false
    groupfns:{}
  # `url` is the path to the restful filter object
  url:"/getFrames"
  # `subscribePath` is the channel the `subscribe` method (websocket/pubsub) uses to listen for events
  subscribePath:"Frame"
  # if `mute` is true, altering the query params will not fire a request to the server.  This is typically used for parent level filtercollections that have other filtercollection bound to it
  mute:false
  # if clearOnFetch is true, the filtercollection will clear its models list for every request (page by page, or changing filters).
  # if clearOnFetch is false, the filtercollection will retain its models list, and add newly fetched values on to its stack (endless scroll pagination)
  clearOnFetch:true

  #initialize / constructor
  initialize: (models,params) =>
    # Create callback stack for functions to be called before and after a fetch
    @callbackStack = {}
    @callbackStack['post'] = []
    @callbackStack['pre'] = []

    # [The mute param](#section-5 "jump to mute examples")
    if params?.mute?
      @mute = params.mute

    # The clearOnFetch param:
    # true: (default) clears collection on fetch.
    # false: retains data in collection (for pagination)
    if params?.clearOnFetch?
      @clearOnFetch = params.clearOnFetch

    # init bound collections in private space
    @_boundCollections = []

    # init sort params in private space
    @_sortParams = _.clone @_defaults

    super(models,params)
    if params?.viewid?
      olap = require 'models/olap'
      @dataview = new olap({id:params.viewid})
      @dataview.fetch({async:false})
      params.url = "chart/data/#{@dataview.get('id')}"

    # ###bindFilter:
    #   An instance of FilterCollection that when changed, bubbles the filter
    #   up through all bound filters.
    #   example:
    #   > Creating a FilterCollection with mute on, then creating
    #   > 5 other FilterCollections bound to the initial instance.
    #   > when you change the initial FilterCollection, all others
    #   > refresh with filter settings
    if params?.bindFilter
      #@bindTo params.bindFilter.subCollection
      params.bindFilter.subCollection @
      @bindFilter = params.bindFilter
      @bindFilter
      @_sortParams = @bindFilter.getSettings()
    else
      @bindFilter = false
    @subToBackfill()

    # Set baseUrl off of default url.  url is changed, baseUrl remains root url
    if params.url?
      @_url = params.url
      @baseUrl = @_url
    else
      @baseUrl = @url
    @_lastUrl = ''

    # Load filter widgets
    # TODO: make these collections
    if !@filters?
      @filters = []
    if !Application.settings.ui_filters_framemetadata?
      Application.settings.ui_filters_framemetadata = []

    return @

  subToBackfill: =>
    if @bindFilter == false
      Application.subscribe("backfill/complete/", @globalRefresh)

  bindTo: (collection) =>
    collection.subCollection @
    @bindFilter = collection
    @_sortParams = @bindFilter.getSettings()

  # Add sub collection
  subCollection: (collection) =>
    @_boundCollections.push collection

  # subscrbe to channel on pubsub
  # TODO: finish this up
  subscribe: (channel,callback=@receive) =>
    if channel
      if @name
        namePath = @name + '/'
      else
        namePath = ''
      Application.socket.removeListener "message:#{@subscribePath}/#{namePath}", callback
      @name = channel
      namePath = @name + '/'
    else
      namePath = ''
    if Application.socket
      Application.subscribe("#{@subscribePath}/#{namePath}", callback)

  #trigger fired when receiving data on the pubsub subscription.
  receive: (data) =>
    _obj = new @model data.data
    if @getParam('sortorder') == -1
      at = 0
    else
      at = (@models.length)
    @add _obj, {at:at}
    return _obj

  # Set sort param.  Bubble up through bound FiltersCollections
  setParam: (key,val) =>
    if key != "skip"
      @resetParam("skip")
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
  getParam:(key,val) =>
    if @_sortParams[key]? and @_sortParams[key] != false
      return @_sortParams[key]
    else if val?
      return val
    else if @_defaults[key]?
      return @_defaults[key]
    else
      return false

  # Get filter library from Application
  loadFilter: (name) ->
    Application.filters[name]

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

  # builds a query based on all bound filter widgets
  alterFilters:() =>
    criteria = []
    _json = {}
    for o in @filters
      val = o.toJson()
      if val
        criteria.push val
    if criteria.length > 0
      _json = {logic:'and',criteria:criteria}
    @setParam 'query', _json
    return

  #returns prepared object for query
  getSettings: (total=false, addParams) =>
    if total
      skip = 0
      limit = @getParam('skip')+@getParam('limit')
    else
      skip=@getParam('skip')
      limit=@getParam('limit')
    _json =
      skip:skip
      query: @getParam 'query'
      sortinfo:
        type: @getParam 'sorttype', ''
        name: @getParam 'sortkey', 'capturetime_epoch'
        order: @getParam 'sortorder'

    if limit != false
      if @dataview?
        _json['limit'] = skip + limit
      else
        _json['limit'] = limit
    if @getParam('groupby')
      _json['groupByField'] = {groupby: @getParam('groupby'), groupfns: @getParam('groupfns')}
    if addParams
      _json = _.extend _json, addParams
    return _json

  # gets url with full db query
  # TODO: map .error to params.error
  getUrl: (total=false, addParams, dataSet=false)=>
    if !dataSet
      dataSet = @getSettings(total, addParams)
    if dataSet.sortinfo.name?
      dataSet.sortinfo.name = encodeURIComponent dataSet.sortinfo.name
    return "/"+JSON.stringify dataSet

  # trigger fired before the fetch method makes request to server
  preFetch:(params)=>
    #if params.modal and !@mute
    #  Application.modal.show(params.modal)
    if !@clearOnFetch
      @_all = @models
    for o in @callbackStack['pre']
      if typeof o == 'function'
        o()
    @callbackStack['pre'] = []
    return

  # trigger fired after the fetch method makes request to server
  postFetch:(fc,data)=>
    console.log data
    #Application.modal.clear()
    if !@clearOnFetch
      if @getParam('sortorder') == -1
        at = 0
      else
        at = (@_all.length)
      # I disabled this because i think we always want paginated data at the pushed on to the stack - Jim
      #@add @_all, {at:at ,silent: true}
      @add @_all, {at:0, silent: true}
      @_all = []
    for o in @callbackStack['post']
      if typeof o == 'function'
        o(data)
    @callbackStack['post'] = []
    @trigger 'reset', @models
    return

  # refreshes the collection from the server
  globalRefresh:=>
    _skip = @getParam('skip')
    callback = =>
    if _skip > 0
      _limit = @getParam('limit')
      #console.log "temp setting from: ",_skip,_limit
      limit = _limit + _skip
      #console.log "to: ",0,limit
      @setParam('skip',0)
      @setParam('limit',limit)
      callback = =>
        #console.log "resetting: ",_skip,_limit
        @setParam('skip',_skip)
        @setParam('limit',_limit)

    @fetch({force:true,filtered:true,modal:false,success:callback})

  setRaw: (response) =>
    @raw = response

  # fetches data from the server
  # params can have `before` or `success` methods passed in.
  #
  # - __before__: fires before the fetch makes request to server
  # - __success__: fires after the fetch makes request to server
  fetch: (params={}) =>
    #console.dir params
    #console.log params
    if !params.modal?
      params.modal = {message:'<p class="large center">Loading<p>',throbber:true}
    if params.filtered and @clearOnFetch == false
      @clearOnFetch = true
      @callbackStack['post'].push => @clearOnFetch = false
    if !params.error?
      params.error = => console.error 'generic request error'
    params['silent'] = true
    @preFetch(params)
    if params.forceRefresh
      @models = []
    total = params.total || false
    _url = @baseUrl+@getUrl(total,params['params']||false)
    for o in @_boundCollections
      #TODO: TRACE WHERE THIS DAMN PARAM IS COMING FROM
      delete params.success
      o.fetch(params)
    if !@mute
      @_all = @models
      if params.before
        @callbackStack['pre'].push params.before
      if params.success
        @callbackStack['post'].push params.success
      params.success = @postFetch
      if @_lastUrl != _url or params.force
        @_lastUrl = _url
        @url = _url
        super(params)
      else if params.success
        params.success()

  # parses data returned by `fetch`.  (after `preFetch` and `fetch`, but before `postFetch`)
  parse: (response) =>
    # check for new olap request
    if response.data?
      @lastavail = response.data?.length || 0
      keys = @dataview.get("dataMap")
      map = @dataview.get("_ormMap")
      frames = []
      for f in response.data
        frame = {id:f.m[0], results:[]}
        meas = {}
        for i,k of keys
          if map.root[k]?
            frame[k] = f.d[i]
          else if map.results[k]?
            fa = k.split(".")
            if !meas[fa[0]]?
              meas[fa[0]] = {}
            meas[fa[0]]['measurement_name'] = fa[0]
            meas[fa[0]][fa[1]] = f.d[i]
        for i,me of meas
          frame.results.push me
        frames.push frame
      @subscribe(response.chart)
      return frames
    else
      @totalavail = response.total_frames
      @lastavail = response.frames?.length || 0
      @setRaw (response)
      #dir = @getParam 'sortorder'
      #if dir and response.frames
      #  response.frames = response.frames.reverse()
      return response.frames