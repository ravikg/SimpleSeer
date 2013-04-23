# Put your handlebars.js helpers here.



#logical functions, thanks to
#https://github.com/danharper/Handlebars-Helpers and js2coffee.org
Handlebars.registerHelper "if_eq", (context, options) ->
  return options.fn(context)  if context is options.hash.compare
  options.inverse context

Handlebars.registerHelper "unless_eq", (context, options) ->
  return options.unless(context)  if context is options.hash.compare
  options.fn context

Handlebars.registerHelper "if_gt", (context, options) ->
  return options.fn(context)  if context > options.hash.compare
  options.inverse context

Handlebars.registerHelper "unless_gt", (context, options) ->
  return options.unless(context)  if context > options.hash.compare
  options.fn context

Handlebars.registerHelper "if_lt", (context, options) ->
  return options.fn(context)  if context < options.hash.compare
  options.inverse context

Handlebars.registerHelper "unless_lt", (context, options) ->
  return options.unless(context)  if context < options.hash.compare
  options.fn context

Handlebars.registerHelper "if_gteq", (context, options) ->
  return options.fn(context)  if context >= options.hash.compare
  options.inverse context

Handlebars.registerHelper "unless_gteq", (context, options) ->
  return options.unless(context)  if context >= options.hash.compare
  options.fn context

Handlebars.registerHelper "if_lteq", (context, options) ->
  return options.fn(context)  if context <= options.hash.compare
  options.inverse context

Handlebars.registerHelper "unless_lteq", (context, options) ->
  return options.unless(context)  if context <= options.hash.compare
  options.fn context

Handlebars.registerHelper "nl2br", (text) ->
  nl2br = (text + "").replace(/([^>\r\n]?)(\r\n|\n\r|\r|\n)/g, "$1" + "<br>" + "$2")
  new Handlebars.SafeString(nl2br)

Handlebars.registerHelper 'epoch', (epoch) ->
  d = new Date parseInt epoch * 1000

  zp = (n) ->
    if n < 10
      n = "0" + n
    n.toString()

  (d.getMonth() + 1) + "/" + zp(d.getDate()) + " " + zp(d.getHours()) + ":" + zp(d.getMinutes()) + ":" + zp(d.getSeconds())

Handlebars.registerHelper 'epochtime', (epoch) ->
  d = new Date parseInt epoch * 1000

  zp = (n) ->
    if n < 10
      n = "0" + n
    n.toString()

  zp(d.getHours()) + ":" + zp(d.getMinutes()) + ":" + zp(d.getSeconds())

Handlebars.registerHelper 'epochdate', (epoch) ->
  d = new Date parseInt epoch * 1000

  zp = (n) ->
    if n < 10
      n = "0" + n
    n.toString()

  (d.getMonth() + 1) + "/" + zp(d.getDate()) + "/" + (1900 + d.getYear())

Handlebars.registerHelper 'featuresummary', (featureset) ->
  unless featureset?
    return
  #TODO, group by featuretype
  ret = ''
  for f in featureset.models
    icon = ""
    if f.icon()
      icon = "<img src=\"" + f.icon() + "\">"
    ret += "<li class=feature>" + icon + f.represent() + "</li>"

  new Handlebars.SafeString(ret)


Handlebars.registerHelper 'featuredetail', (features) ->
  unless features[0].tableOk()?
    return new Handlebars.SafeString features[0].represent()

  ret = "<table class=\"tablesorter\"><thead><tr>"
  for th in features[0].tableHeader()
    ret += "<th>" + th + "</th>"
  ret += "</tr></thead><tbody>\n"

  for tr in features
     ret += "<tr>"
     for td in tr.tableData()
       ret += "<td>" + td + "</td>"
     ret += "</tr>"

  ret += "</tbody></table>"
  new Handlebars.SafeString(ret)

Handlebars.registerHelper 'featurelist', (features = {}) ->
  if !@featureStyles?
    @featureStyles = {}
  if !features
  	features = []
  ret = ""
  for fetName,feature of features
    keys = feature.tableHeader() || []
    values = feature.tableData() || []
    metadata = feature.metadata(fetName)
    for key,val of metadata
      _lk = "["+val.labelkey+"] " || ""
      ret += '<div style="clear:both;">'
      ret += '<p class="item-detail"><span class="featureLabel">'+_lk+'</span>' + val.title + ':</p>'
      ret += '<p class="item-detail-value" style="'+(val.style || @featureStyles[key] || "")+'">'+val.value+'<span>'+val.units+'</span></p>'
      ret += "</div>"
  return new Handlebars.SafeString(ret)

# Usage: {{#key_value obj}} Key: {{key}} // Value: {{value}} {{/key_value}}
Handlebars.registerHelper "key_value", (obj, fn) ->
  buffer = []
  retVal = []
  key = undefined
  for key of obj
    if obj.hasOwnProperty(key)
      buffer.push key
  _s = buffer.sort()
  for k in _s
    retVal += fn(
      key: k
      value: obj[k]
    )
  retVal

Handlebars.registerHelper "not_in", (context, options) ->
  if options.hash.needle in options.hash.haystack
    options.inverse context
  else
    options.fn context

Handlebars.registerHelper "localize_dt", (epoch, options) ->
  dt = moment.utc(epoch)
  if options.hash.format?
    f = options.hash.format
  else
    f = "MM-DD-YYYY"
  dt.local()
  return new Handlebars.SafeString dt.format(f)

Handlebars.registerHelper "log", (value) ->
  #console.log "Handlebars Log: ", value
  return new Handlebars.SafeString ""

Handlebars.registerHelper "resultlist", (results) ->
  tpl = ""
  if results.length is 0
    tpl += "<div data-use=\"no-results\" class=\"centered\">Part Failed: No Results</div>"
  else
    for result in results
      value = result.numeric or ""
      unless value is undefined 
        obj = SimpleSeer.measurements.where({name:result.measurement_name})[0]
        label = obj.get('label')
        if obj.get('units')
          unit = if obj.get('units') is "deg" then "&deg;" else " (#{obj.get('units')})"
        else
          unit = ""
        if value is "" then unit = "--"
        tpl += "<div class=\"elastic interactive\">#{label}:<span>#{value}#{unit}</span></div>"
  return new Handlebars.SafeString tpl

Handlebars.registerHelper "metalist", (results, template) ->
  tpl = ""
  for key in template
    label = key
    value = results[key] or ""
    tpl += "<div class=\"elastic spacedown\">#{label}:<span>#{value}</span></div>"
  return new Handlebars.SafeString tpl

Handlebars.registerHelper "capturetime", (time) ->
  str = new moment(parseInt(time)).format("M/D/YYYY h:mm a")
  return new Handlebars.SafeString str
