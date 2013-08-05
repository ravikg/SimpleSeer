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
    "click button[action]": "handleAction"

  initialize: =>
    $('#modal').html @render().el
    super()

  getRenderData: =>
    options: @options

  reset: =>
    for i of @callbacks
      @callbacks[i] = []

  isVisible: =>
    return @$el.is(":visible")

  addCallback: (type, func) =>
    if @callbacks[type]? and typeof func == 'function'
      @callbacks[type].push func
    return

  setMinorText:(value) =>
    @$("p.minor").html value

  show:(options={}) =>
    @reset()
    if !options.gutter? and options.submitText? or options.cancelText? or options.buttons?
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
    [values, errors] = FormBuilder.getValues(@$(".form"))
    return [values, errors]

  displayValidationErrors:(errors) =>
    @$(".form .invalid").removeClass("invalid")
    for item in errors
      item = (_.where @options.form, {id: item})?[0]
      if item.type is "text" or item.type is "password"
        el = @$(".form *[data-key=#{item.id}]")
        el.addClass("invalid")
        el.focus()

  handleAction:(e) =>
    action = $(e.target).attr("action")
    switch action
      when "submit"
        @handleSubmit()
      when "cancel"
        @handleCancel()
      else
        button = _.where @options.buttons, {action: action}
        if button?[0]?
          [values, errors] = @getFormValues()
          button[0].fn?(values || null)

  handleSubmit: =>
    [values, errors] = @getFormValues()
    if errors?.length
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


