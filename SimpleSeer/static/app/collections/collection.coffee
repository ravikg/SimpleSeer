module.exports = class Collection extends Backbone.Collection
  ajaxTried: 0
  ajaxMaxAttempts: 10
  ajaxTimeout: 8000
  cachebust: true

  sync: =>
    args = arguments
    args[2]?.timeout = @ajaxTimeout
    Backbone.sync.apply( this, args )
    .done =>
      @ajaxTried = 0
      SimpleSeer.modal.clear()
    .fail (response, response_type, HTTP_status) =>

      if (@ajaxMaxAttempts is 0 or @ajaxTried < @ajaxMaxAttempts) and response.status != 500

        SimpleSeer.modal.show
          title: "Connecting",
          throbber: true,
          message: "<p class='minor center'>Attempting connection to server.</p>"

        @ajaxTried = @ajaxTried+1
        @sync.apply( this, args )

      else if response.status == 500

        _rep = {}
        _rep[response.status] = response.responseText
        $.ajax
          type:"POST"
          url:"/log/error"
          data:
            "location":Backbone.history.fragment
            "response":_rep
          dataType:"json"
        return

      else

        SimpleSeer.modal.show
          title: "Error",
          message: "<p class='minor center'>Could not connect to the server. Please contact the system administrator.</p>"

        @ajaxTried = 0
        console.error "Error: Lost Connection (collection.coffee)"

  fetch: (args) =>
    if @cachebust
      @url = @url.replace /(\?cachebust\=\d+)/g, ""
      @url += "?cachebust="+new moment().valueOf()
    super(args)
