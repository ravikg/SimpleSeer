module.exports = class Collection extends Backbone.Collection

  initialize: =>
    @tries = 0
    @maxTries = 10
    @timeout = 15000 #15 seconds
    @cachebust = true

  sync: =>
    args = arguments
    args[2]?.timeout = @timeout
    Backbone.sync.apply( this, args )
    .done =>
      @tries = 0
      #SimpleSeer.modal.clear()
    .fail (response, response_type, HTTP_status) =>
      if (@maxTries is 0 or @tries < @maxTries) and response.status != 500
        #SimpleSeer.modal.show
        #  title: "Connecting",
        #  throbber: true,
        #  message: "<p class='minor center'>Attempting connection to server.</p>"
        @tries = @tries + 1
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
        #SimpleSeer.modal.show
        #  title: "Error",
        #  message: "<p class='minor center'>Could not connect to the server. Please contact the system administrator.</p>"
        @tries = 0

  fetch: (args) =>
    if @cachebust
      @url = @url.replace /(\?cachebust\=\d+)/g, ""
      @url += "?cb="+new moment().valueOf()
    super(args)
