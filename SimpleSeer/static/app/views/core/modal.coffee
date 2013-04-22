View = require 'views/core/view'
application = require 'application'
template = require './templates/modal'

###
SimpleSeer.modal.show({message:'I demand user interaction!',
                       okMessage:'hi!',
                       cancelMessage:'Cancel',
                       inputMessage:"edit me!",
                       throbber:false,
                       success:function(options){console.log(options.userInput);},
                       cancel:function(){alert('canceled');}
                       });
###
module.exports = class modal extends View
  id: "simpleseer-modal"
  tagName: "div"
  className: "modal-body"
  template: template
  _callbacks:
    cancel: []
    success: []
    
  events:
    'click .ok-button':'onSuccess'
    'click .cancel-button':'onCancel'

  initialize: =>
    @_reset()
    $('#modal').html @render().el

    inputBox = @$el.find("input")
    inputBox.live("keypress", (e, ui)=>
      if (e.which == 13) #Enter
        @onSuccess()
    )
      
    super()
    
  _reset:=>
    for i of @_callbacks
      @_callbacks[i] = []
    @$el.find(".message").html('')
    return

  # options:
  #   message:       (string)   Message to display on modal
  #   success:       (function) function to push on to the callback stack
  #                             that will execute when the modal hides
  #                             due to any action other than cancel
  #   cancel:        (function) function to push on the the callback stack
  #                             that will execute when the modal cancel
  #                             action is called
  #   okMessage:     (string)   Enables OK button and uses val as button text
  #   cancelMessage: (string)   Enables Cancel button and uses val as button text
  #   inputMessage:  (string)   Enables user input box and applies default value
  #   throbber:      (bool)     Use throbber graphic
  show:(options={throbber:true}) =>

  	#throbber
    if options.throbber
      @$el.find('#throbberGraphic').show().removeClass("hidden")
    else
      @$el.find('#throbberGraphic').hide().addClass("hidden")

    #message
    if options.message
      @$el.find(".message").html(options.message).show()
    else 
      @$el.find(".message").hide()
    
    #success and cancel
    for i in ['success','cancel']
      if options[i]?
        @addCallback i, options[i]
    
    #cancelMessage
    ele = @$el.find('.cancel-button')
    if options.cancelMessage?
      ele.html(options.cancelMessage)
      ele.show()
    else
      ele.hide()

    #okMessage
    ele = @$el.find('.ok-button')
    if options.okMessage?
      ele.html(options.okMessage)
      ele.show()
    else
      ele.hide()    
    
    #inputMessage
    ele = @$el.find('input')
    if options.inputMessage?
      ele.attr('value', "");
      ele.attr('placeholder',options.inputMessage)
      ele.show()
    else
      ele.hide()

    #show modal
    @$el.show()
    if options.inputMessage?
      ele.get(0).focus()
    return
  
  addCallback:(type,func) =>
    if @_callbacks[type]? and typeof func == 'function'
      @_callbacks[type].push func
    return

  # values:
  #   userInput:     (string)   Value entered by user
  #   action:        (string)   Action taken ['DEFAULT','OK']
  onSuccess:(values={}) =>
  	if !values.action?
      values.action = 'DEFAULT'
  	if !values.userInput?
      values.userInput = @$el.find('input').val()
    @$el.hide()
    for f in @_callbacks['success']
      f(values)
    @_reset()
    return
  
  onCancel: =>
    @$el.hide()
    for f in @_callbacks['cancel']
      f()
    @_reset()
    return
