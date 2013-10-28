FilterCollection = require "./core/filtercollection"

module.exports = class Table extends FilterCollection
  subscribePath: "Frame"
  
  initialize: (models, args={}) =>
    @filterRoot = "Chart"
    @name = args.name || ''
    @id = args.id
    if args.url
      _url = args.url
    else
      _url = "/chart/data/"
    args.url = _url+@id
    if args.view?
      @view = args.view
    super(models, args)
    @setParam 'sortkey', 'capturetime_epoch'
    @setParam 'sortorder', -1
    if args.realtime
      @realtime = true
    else
      @realtime = false
    return @

  receive: (data) =>
    f = @parse(data.data.m)
    @reset(f)
    return f

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