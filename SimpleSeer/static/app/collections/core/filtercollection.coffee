Collection = require "collections/collection"
application = require 'application'
#FramelistFrameView = require './framelistframe_view'
#context = require '../models/core/context'

###
Simple Query:
"query":{"logic":"and","criteria":[{"type":"left","eq":1,"name":"results.state"}]}

Logical Query:
"query":{"logic":"and","criteria":[{"type":"left","eq":1,"name":"results.state","logic":"and","criteria":[{"type":"left","eq":1,"name":"results.state"}]}]}
###

#groupfns: list, first, last, max, min, avg, sum

module.exports = class FilterCollection extends Collection
  _defaults:
    sortkey:false
    sortorder:-1
    sorttype:false
    skip:0
    limit:20
    query:{}
    groupby:false
    groupfns:{}
  url:"/getFrames"
  subscribePath:"frame"
  mute:false
  clearOnFetch:true
  
  
  initialize: (models,params) =>
    #if params.context?
      #@context = new context({name:params.context})
      #@context.fetch()
      #  success: () =>
      #    for menuItem of @context.get('menuItems')
      #      f = 1

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

    super(models,params)
    
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
    if params.url?
      @url = params.url
    @baseUrl = @url
    
    # Load filter widgets
    # TODO: make these collections
    if !@filters?
      @filters = []
    if !application.settings.ui_filters_framemetadata?
      application.settings.ui_filters_framemetadata = []

    # Render filter widgets
    if params.view
      @view = params.view
      i = 0
      for o in application.settings.ui_filters_framemetadata
        #@filters.push @view.addSubview o.type+"_"+o.field_name, @loadFilter(o.format), '#filter_form', {params:o,collection:@,append:"filter_" + i}
        i+=1
    return @

  # Add sub collection
  subCollection: (collection) =>
    @_boundCollections.push collection

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
  
  # Sync filters
  #"query":{"logic":"and","criteria":[{"type":"left","eq":1,"name":"results.state"}]}

  ###
  # select * where datetime = 123456789 and (results.left.state = 1 or results.right.state = 1) 
    "query":{
      "logic":"and",
      "criteria":[
        {
          "type":"frame",
          "eq":123456789,
          "name":"dt"
        },
        {
          "logic":"or",
          "criteria":[
            {          
              "type":"left",
              "eq":1,
              "name":"results.state"
            },
            {          
              "type":"right",
              "eq":1,
              "name":"results.state"
            }
          ]
        }
      ]
    }
  ###
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
      _json['groupByField'] = 
        groupby: @getParam('groupby')
        groupfns: @getParam('groupfns')
    
    #if groupByField
    #  _json['groupByField'] = groupByField
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
    for i,o of @callbackStack['post']
      if typeof o == 'function'
        o()
    @callbackStack['post'] = []
    return

  globalRefresh:=>
    @fetch({force:true})

  setRaw: (response) =>
    @raw = response

  fetch: (params={}) =>
    if params.forceRefresh
      @models = []
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
    @lastavail = response.frames?.length || 0
    @setRaw (response)
    return response.frames
