SubView = require 'views/core/subview'
template = require './templates/editabletextfield'
application = require 'application'

module.exports = class editabletextfield extends SubView
  template:template
  defaultString: "----"
  text: undefined
  edit: false
  maxLength: undefined
  minLength: undefined
  msg: ''

  initialize: =>
    super()
    if !@text
      @text = @defaultString

    if @options.maxLength?
      @maxLength = @options.maxLength
    if @options.minLength?
      @minLength = @options.minLength

  events: =>
    'click .edit':'clickEdit'
    'click .submit':'clickSubmit'
    'dblclick .textfield':'clickEdit'
    'keyup input':'keypress'

  keypress: (e) =>
    if e.keyCode == 13 and @edit == true
      @$el.find('.submit').click()
    if e.keyCode == 27 and @edit == true
      @edit = false
      @render()

  clickEdit: (e) =>
    if @edit == false
      @edit = true
      @$el.find('.edit').css('display', 'none')
      @$el.find('.submit').css('display', 'block')
      value = @$el.find('.text').html()
      html = '<input type="text" value="' + value + '" '
      if @maxLength
        html += 'maxlength="' + @maxLength + '" '
      html += '/>'
      @$el.find('.text').html(html).addClass('no-padding')
      @$el.find('input').focus()
    else
      @edit = false
      @render()


  clickSubmit: (e) =>
    value = @$el.find('input').val()

    err = 0
    @msg = ""
    if @minLength
      if value.length < @minLength
        @msg += "Length must be greater then " + @minLength
        err++
    if @maxLength
      if value.length > @maxLength
        @msg += "Length must be less then " + @maxLength
        err++

    if err
      application.alert(@msg, "error")
      @$el.find('input').css("border-color", "#FF0000").css("background-color", "#FF9999").focus()
    else
      @edit = false
      application.alert("", "clear")
      @update(value)
  
  getRenderData:=>
    text:@text
  
  update: (value)=>
    console.log "@TODO: Do something with this value: ", value
    @text = value
    @render()
