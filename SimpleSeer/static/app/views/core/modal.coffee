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
  defaults:
    submitText: "OK"
    cancelText: "Cancel"
    gutter: false
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
    options: _.extend @defaults, @options

  reset: =>
    for i of @_callbacks
      @_callbacks[i] = []

  addCallback: (type, fn) =>
    if @callbacks[type]? and typeof func == 'function'
      @callbacks[type].push func
    return

  show:(options={}) =>
    if !options.gutter? and options.submitText? or options.cancelText?
      # Display buttons if text is specified
      options.gutter = true
    @options = options
    for i in ['submit','cancel']
      if options[i]?
        @addCallback i, options[i]
    @render()
    @$el.fadeIn(120).parents("#modal").addClass("visible")

  clear: =>
    @$el.fadeOut(120).parents("#modal").removeClass("visible")
    @reset()

  getFormValues: =>
    values = {}
    for item in @options.form
      values[item.id] = @$(".form *[data-key=#{item.id}]").val()
    return values

  handleSubmit: =>
    console.log @getFormValues()
    @clear()
    for i in @callbacks['submit']
      i()

  handleCancel: =>
    @clear()
    for i in @callbacks['cancel']
      i()

  onSuccess: =>

  onCancel: =>


