[Application, View, Template] = [
  require("application"),
  require("views/core/view"),
  require("./templates/modal")
]

module.exports = class Modal extends View
  id: "simpleseer-modal"
  tagName: "div"
  className: "modal-body"
  template: Template
  options: {}
  callbacks:
    submit: []
    cancel: []

  events: =>
    "click button[action=submit]": "handleSubmit"
    "click button[action=cancel]": "handleCancel"

  initialize: =>
    $('#modal').html @render().el
    super()

  getRenderData: =>
    options: @options

  reset: =>
    for i of @callbacks
      @callbacks[i] = []

  addCallback: (type, func) =>
    if @callbacks[type]? and typeof func == 'function'
      @callbacks[type].push func
    return

  show:(options={}) =>
    @reset()
    if !options.gutter? and options.submitText? or options.cancelText?
      options.gutter = true # Display buttons if text is specified
    @options = options
    for i in ['submit','cancel']
      if options[i]?
        @addCallback i, options[i]
    @render()
    @$el.fadeIn(120).parents("#modal").addClass("visible")

  afterRender: =>
    if @options.form
      $(@$(".form input[type=text]").get(0)).focus()

  clear: =>
    @$el.fadeOut(120).parents("#modal").removeClass("visible")
    @reset()

  getFormValues: =>
    values = {}
    errors = []
    for item in @options.form
      if item.type is "text" or item.type is "password"
        values[item.id] = @$(".form *[data-key=#{item.id}]").val()
      if item.type is "textarea"
        values[item.id] = @$(".form *[data-key=#{item.id}]").html()
      if item.type is "radio"
        values[item.id] = @$(".form *[data-key=#{item.id}]:checked").val()
      if item.type is "select"
        if item.multiple is true
          items = @$(".form *[data-key=#{item.id}] option:selected")
          values[item.id] = []
          for box in items
            values[item.id].push $(box).val()
        else
          values[item.id] = @$(".form *[data-key=#{item.id}] option:selected").val()
      if item.type is "checkbox"
        items = @$(".form *[data-key=#{item.id}]:checked")
        values[item.id] = []
        for box in items
          values[item.id].push $(box).val()
      if item.required is true and (!values[item.id]? or values[item.id] is "")
        errors.push item.id
    return [values, errors]

  displayValidationErrors:(errors) =>
    @$(".form .invalid").removeClass("invalid")
    for item in errors
      item = (_.where @options.form, {id: item})?[0]
      if item.type is "text" or item.type is "password"
        el = @$(".form *[data-key=#{item.id}]")
        el.addClass("invalid")
        el.focus()

  handleSubmit: =>
    [values, errors] = @getFormValues()
    if errors.length
      @displayValidationErrors(errors)
    else
      callbacks = _.clone @callbacks
      @clear()
      for i in callbacks['submit']
        i(values)

  handleCancel: =>
    callbacks = _.clone @callbacks
    @clear()
    for i in callbacks['cancel']
      i()

  onSuccess: => @clear()
  onCancel: => @clear()


