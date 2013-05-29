SubView = require 'views/core/subview'
template = require './templates/editabletextfield'
application = require 'application'

module.exports = class editabletextfield extends SubView
  template:template
  defaultString: "----"
  text: undefined
  edit: false

  initialize: =>
    super()
    if !@text
      @text = @defaultString

  events: =>
    'click .edit':'clickEdit'
    'click .submit':'clickSubmit'
    'dblclick .textfield':'clickEdit'
    'keyup input':'keypress'

  keypress: (e) =>
    if e.keyCode == 13 and @edit == true
      @$el.find('.submit').click()

  clickEdit: (e) =>
    if @edit == false
      @edit = true
      @$el.find('.edit').css('display', 'none')
      @$el.find('.submit').css('display', 'block')
      value = @$el.find('.text').html()
      html = '<input type="text" value="' + value + '" />'
      @$el.find('.text').html(html)
      @$el.find('input').focus()


  clickSubmit: (e) =>
    @edit = false
    value = @$el.find('input').val()
    @update(value)
  
  getRenderData:=>
    text:@text
  
  update: (value)=>
    console.log "@TODO: Do something with this value: ", value
    @text = value
    @render()
