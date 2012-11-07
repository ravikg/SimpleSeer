# Base class for all collections.
Backbone = if describe? then require('backbone') else window.Backbone

module.exports = class Collection extends Backbone.Collection
  ajaxTried: 0

  sync: =>
    args = arguments
    Backbone.sync.apply( this, args )
    .done =>
      @ajaxTried = 0
    .fail (response, response_type, HTTP_status) =>
      if @ajaxTried < 3 and response.status != 500
        @ajaxTried = @ajaxTried+1
        @sync.apply( this, args )
      else if response.status == 500
        report = {location:window.location, response:response}
        #todo: report error from here
      else
        @ajaxTried = 0
        $('#lost_connection').dialog 'open'
