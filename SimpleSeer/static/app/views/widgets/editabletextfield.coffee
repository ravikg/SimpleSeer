SubView = require 'views/core/subview'
template = require './templates/editabletextfield'
application = require 'application'

module.exports = class editabletextfield extends SubView
  template:template
  defaultString: ""
  text: undefined
  edit: false
  blur: false
  submit_id: undefined
  input_id: undefined
  maxLength: undefined
  minLength: undefined
  msg: ''

  initialize: =>
    super()
    if @options.defaultString?
      @defaultString = @options.defaultString
    if @options.submit_id?
      @submit_id = @options.submit_id
    if @options.input_id?
      @input_id = @options.input_id
    if @options.maxLength?
      @maxLength = @options.maxLength
    if @options.minLength?
      @minLength = @options.minLength
    if @options.regexps?
      @regexps = @options.regexps

    if !@text
      @text = @defaultString

    $(document).on "click", "body", (e) =>
      if @blur is true and @edit is true and e.target.id != @submit_id
        @edit = false
        @blur = false
        @render()

    $(document).on "keydown", "body", (e) =>
      if e.keyCode == 9
        if @edit is true and e.target.id == @input_id
          @$el.find('.submit').click()
          @blur = false

  events: =>
    'click .edit':'clickEdit'
    'click .submit':'clickSubmit'
    'dblclick .textfield':'clickEdit'
    'keyup input':'keypress'
    'blur input':'blurInput'

  blurInput: (e) =>
    @blur = true

  keypress: (e) =>
    if e.keyCode == 13 and @edit == true
      @$el.find('.submit').click()
      @blur = false
    if e.keyCode == 27 and @edit == true
      @edit = false
      @blur = false
      @render()

  clickEdit: (e) =>
    if @edit == false
      @blur = false
      @edit = true
      @$el.find('.edit').css('display', 'none')
      @$el.find('.submit').css('display', 'block')
      value = @$el.find('.text').html()
      html = '<input type="text" value="' + value + '" '
      if @input_id
        html += 'id="' + @input_id + '" '
      if @maxLength
        html += 'maxlength="' + @maxLength + '" '
      html += '/>'
      @$el.find('.text').html(html).addClass('no-padding')
      @$el.find('input').focus()
    else
      @edit = false
      @blur = false
      @render()

  clickSubmit: (e) =>
    value = @$el.find('input').val()

    err = 0
    @msg = ""
    if @minLength
      if value.length < @minLength
        @msg += "Length must be at least (" + @minLength + ") characters<br/>"
        err++
    if @maxLength
      if value.length > @maxLength
        @msg += "Length must be no more than (" + @maxLength + ") characters<br/>"
        err++

    _.each @regexps, (regexp) =>
      exp = new RegExp(regexp.exp)
      if value.search(exp) is -1
        @msg += regexp.msg + "<br/>"
        err++

    if err
      application.alert(@msg, "error")
      @$el.find('input').css("border-color", "#FF0000").css("background-color", "#FF9999").focus()
    else
      @edit = false
      @blur = false
      application.alert("", "clear")
      @update(value)
  
  getRenderData:=>
    text:@text
    submit_id:@submit_id
  
  update: (value)=>
    console.log "@TODO: Do something with this value: ", value
    @text = value
    @render()
