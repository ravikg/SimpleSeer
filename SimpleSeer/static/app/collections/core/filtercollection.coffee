Collection = require "collections/collection"
application = require 'application'

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
  subscribePath:"frame"
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

    super(models,params)
    
    # ###bindFilter:
    #   An instance of FilterCollection that when changed, bubbles the filter
    #   up through all bound filters.
    #   example:
    #   > Creating a FilterCollection with mute on, then creating
    #   > 5 other FilterCollections bound to the initial instance.
    #   > when you change the initial FilterCollection, all others
    #   > refresh with filter settings
    if params.bindFilter
      params.bindFilter.subCollection @
      @bindFilter = params.bindFilter
      @bindFilter
      @_sortParams = @bindFilter.getSettings()
    else
      @bindFilter = false
    
    # Set baseUrl off of default url.  url is changed, baseUrl remains root url
    if params.url?
      @url = params.url
    @baseUrl = @url
    
    # Load filter widgets
    # TODO: make these collections
    if !@filters?
      @filters = []
    if !application.settings.ui_filters_framemetadata?
      application.settings.ui_filters_framemetadata = []

    return @

  # Add sub collection
  subCollection: (collection) =>
    @_boundCollections.push collection

  # subscrbe to channel on pubsub
  # TODO: finish this up
  subscribe: (channel,callback=@receive) =>
    if channel?
      if @name
        namePath = @name + '/'
      else
        namePath = ''
      application.socket.removeListener "message:#{@subscribePath}/#{namePath}", callback
      @name = channel
    #if application.debug
      #console.info "series:  subscribing to channel "+"message:#{@subscribePath}/#{namePath}"
    if application.socket
      application.socket.on "message:#{@subscribePath}/#{namePath}", callback
      if !application.subscriptions["#{@subscribePath}/#{namePath}"]
        application.subscriptions["#{@subscribePath}/#{namePath}"] = application.socket.emit 'subscribe', "#{@subscribePath}/#{namePath}"
  #trigger fired when receiving data on the pubsub subscription.
  receive: (data) =>
    console.log data
    
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
      limit:limit
      query: @getParam 'query'
      sortinfo:
        type: @getParam 'sorttype', ''
        name: @getParam 'sortkey', 'capturetime_epoch'
        order: @getParam 'sortorder'
        
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
    "/"+JSON.stringify dataSet

  # trigger fired before the fetch method makes request to server 
  preFetch:()=>
    application.modal.show()
    if !@clearOnFetch
      @_all = @models
    for o in @callbackStack['pre']
      if typeof o == 'function'
        o()
    @callbackStack['pre'] = []
    return
  
  # trigger fired after the fetch method makes request to server 
  postFetch:()=>
    application.modal.onSuccess()
    if !@clearOnFetch
      if @getParam 'sortorder' == -1
        at = 0
      else
        at = (@models.length - 1)
      @add @_all, {at:at ,silent: true}
      @_all = []
    for i,o of @callbackStack['post']
      if typeof o == 'function'
        o()        
    @callbackStack['post'] = []
    @trigger 'reset', @models
    return

  # refreshes the collection from the server
  globalRefresh:=>
    @fetch({force:true})

  setRaw: (response) =>
    @raw = response

  # fetches data from the server
  # params can have `before` or `success` methods passed in.
  #
  # - __before__: fires before the fetch makes request to server
  # - __success__: fires after the fetch makes request to server
  fetch: (params={}) =>
    if params.filtered and @clearOnFetch == false
      @clearOnFetch = true
      @callbackStack['post'].push => @clearOnFetch = false

    params['silent'] = true
    @preFetch()
    if params.forceRefresh
      @models = []
    total = params.total || false
    _url = @baseUrl+@getUrl(total,params['params']||false)
    for o in @_boundCollections
      o.fetch(params)
    if !@mute
      @_all = @models
      @callbackStack['pre'].push params.before
      @callbackStack['post'].push params.success
      params.success = @postFetch
      if @url != _url or params.force
        @url = _url
        super(params)
      else if params.success
        params.success()
  
  # parses data returned by `fetch`.  (after `preFetch` and `fetch`, but before `postFetch`)
  parse: (response) =>
    @totalavail = response.total_frames
    @lastavail = response.frames?.length || 0
    @setRaw (response)
    dir = @getParam 'sortorder'
    if dir and response.frames
      response.frames = response.frames.reverse()
    return response.frames
