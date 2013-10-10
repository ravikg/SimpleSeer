# Put your handlebars.js helpers here.

Handlebars.registerHelper "eqperh", (context, options) ->
  return "height: #{1/context.length*100}%"

Handlebars.registerHelper "eqperw", (context, options) ->
  return "width: #{1/context.length*100}%"

#logical functions, thanks to
#https://github.com/danharper/Handlebars-Helpers and js2coffee.org
Handlebars.registerHelper "if_eq", (context, options) ->
  return options.fn(context)  if context is options.hash.compare
  options.inverse context

Handlebars.registerHelper "unless_eq", (context, options) ->
  return options.fn(context)  unless context is options.hash.compare
  options.inverse context

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

Handlebars.registerHelper "raw", (text) ->
  new Handlebars.SafeString(text)

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
  console.log "Handlebars Log: ", value
  return new Handlebars.SafeString ""

Handlebars.registerHelper "resultlist", (results, blacklist,text="No Results") ->
  tpl = ""

  r = 0

  _.each results, (result) =>
    if result.state?
      r++

  count = 0

  if !results or results.length is 0
    tpl += "<div data-use=\"no-results\" class=\"centered\">#{text}</div>"
  else

    results.map  ((item) => item.mmm = SimpleSeer.measurements.where({name:item.measurement_name})[0])
    results.sort ((a, b) =>
      k1 = a.mmm.get('labelkey')
      k2 = b.mmm.get('labelkey')
      if k1 > k2 then return 1
      if k1 is k2 then return 0
      if k1 < k2 then return -1
    )
    for result in results
      unless ~blacklist.fields.indexOf(result.measurement_name)
        value = if result.numeric? then result.numeric.toFixed(result.mmm.get("fixdig")) else if result.string? then result.string else undefined
        if value
          count++
          obj = result.mmm
          label = "#{obj.get('label')}"
          if obj.get('units')
            unit = if obj.get('units') is "deg" then "&deg;" else " (#{obj.get('units')})"
          else
            unit = ""
          if value is "" then unit = "--"
          tpl += "<div class=\"elastic interactive #{if result.state is 1 then "fail" else "pass"}\" data-feature=\"#{result.measurement_name}\"><span class=\"label\">#{label}:</span><span class=\"value\">#{value}#{unit}</span><div class=\"clearfix\"></div></div>"
  
    if count == 0
      tpl += "<div data-use=\"no-results\" class=\"centered\">#{text}</div>"    

  return new Handlebars.SafeString tpl

Handlebars.registerHelper "metalist", (results, template) ->
  tpl = ""
  for key in template
    label = key
    value = results[key] or ""
    tpl += "<div class=\"elastic spacedown\">#{label}:<span class=\"value\">#{value}</span></div>"
  return new Handlebars.SafeString tpl

Handlebars.registerHelper "editablemetalist", (results={}, template) ->
  tpl = ""
  for key in template
    label = key
    value = results[key] or ""
    tpl += "<div class=\"elastic spacedown\"><span class=\"label\">#{label}</span><span class=\"input\"><input class=\"value\" name=\"#{label}\" value=\"#{value}\" /></span></div>"
  return new Handlebars.SafeString tpl

Handlebars.registerHelper "capturetime", (time) ->
  str = new moment(parseInt(time)).format("M/D/YYYY h:mm a")
  return new Handlebars.SafeString str

Handlebars.registerHelper "tolstate", (results) ->
  len = _.where(results, {state: 1}).length
  if results and (len > 0)
    return "fail"
  else
    return "pass"

Handlebars.registerHelper "formbuilder", (form) ->
  str = "<div data-formbuilder='1'>"
  for element in form
    str += "<div data-id=\"#{element.id}\""
    if element.required
      str += " data-required=\"required\""
    str += ">"
    str += "<label>#{element.label}"
    if element.required
      str += "<span>*</span> "
    str += ":</label><br>"
    switch element.type
      when "text"
        str += "<input type=\"text\" data-key=\"#{element.id}\" value=\"#{element.value or ''}\">"
      when "password"
        str += "<input type=\"password\" data-key=\"#{element.id}\" value=\"#{element.value or ''}\">"
      when "textarea"
        str += "<textarea data-key=\"#{element.id}\">#{element.value or ''}</textarea>"
      when "radio"
        for option in element.values
          str += "<input type=\"radio\" name=\"#{element.id}\" data-key=\"#{element.id}\" value=\"#{option.value}\"> #{option.name}<br>"
      when "checkbox"
        for option in element.values
          str += "<input type=\"checkbox\" name=\"#{element.id}\" data-key=\"#{element.id}\" value=\"#{option.value}\"> #{option.name}<br>"
      when "select"
        str += "<select data-key=\"#{element.id}\" #{if element.multiple then "multiple=\"multiple\"" else ""}>"
        for option in element.values
          str += "<option value=\"#{option.value}\">#{option.name}</option>"
        str += "</select>"
    str += "</div>"
  str += "</div>"
  return new Handlebars.SafeString str

window.FormBuilder = {
  getValues:(element) =>
    values = {}
    errors = []
    element = element.find("[data-formbuilder=1]")
    if element[0]?
      for item in element.find("[data-key]")
        item = $(item)
        id = item.data("key")
        tag = item.get(0).tagName
        type = tag
        required = item.parent().data("required") is "required"
        if tag is "INPUT"
          type = item.attr("type")
        if (type is "text" or item.type is "password")
          values[id] = item.val()
        if (type is "textarea")
          values[id] = item.html()
        if (type is "radio")
          values[id] = item.parent().find("[data-key=#{id}]:checked").val()
        if (type is "select")
          if item.multiple is true
            items = item.parent().find("[data-key=#{id}] option:selected")
            values[id] = []
            for box in items
              values[id].push $(box).val()
          else
            values[id] = item.parent().find("[data-key=#{id}] option:selected").val()
        if (type is "checkbox")
          items = item.parent().find("[data-key=#{id}]:checked")
          values[id] = []
          for box in items
            values[id].push $(box).val()
        if (required is true and (!values[id]? or values[id] is ""))
          errors.push id
    return [values, errors]
}
