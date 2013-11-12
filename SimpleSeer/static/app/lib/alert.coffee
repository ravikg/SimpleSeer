
module.exports = class Alert

  initialize: =>
    Application.subscribe("alert/", @receive)

  receive:(data) =>
    type = data.data.severity
    message = data.data.message
    switch type
      when "clear"
        @clearAll()
      when "redirect"
        @redirect(message)
      else
        @_alert(message, type)

  clearAll: =>

  redirect:(location) =>
    if location is "@rebuild"
      window.location.reload()
    else
      def = window.location.hash
      Application.router.navigate(message || def, true)

  _alert:(message, severity) =>
    console[severity](message)


