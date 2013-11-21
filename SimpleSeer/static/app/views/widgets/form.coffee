[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/form")
]

module.exports = class Form extends SubView
  template: Template

  getRenderData: =>
    items = []
    for item in @options.form
      items.push(item)
    return {items: items}

  reset: =>
    keys = @$("[data-key]")
    for item in keys
      item = $(item)
      tag = item.get(0).tagName
      if (tag is "INPUT") then type = item.attr("type")
      type = type.toLowerCase()

      if (type in ["text", "password"])
        item.val(item.data("default"))
      if (type is "textarea")
        item.html(item.data("default"))
      if (type is "radio")
        item.parents(".item").find("[data-key=#{id}]:checked").removeAttr("checked")
      if (type is "select")
        item.val(item.data("default"))
      if (type is "checkbox")
        item.parents(".item").find("[data-key=#{id}]:checked").removeAttr("checked")     

  submit: =>
    values = {}
    errors = []

    keys = @$("[data-key]")
    for item in keys
      item = $(item)
      id = item.data("key")
      tag = item.get(0).tagName
      type = tag
      required = item.parent().data("required") is "required"

      if tag is "INPUT" then type = item.attr("type")
      type = type.toLowerCase()

      if (type in ["text", "password"])
        values[id] = item.val()
      if (type is "textarea")
        values[id] = item.html()
      if (type is "radio")
        values[id] = item.parents(".item").find("[data-key=#{id}]:checked").val()
      if (type is "select")
        if item.multiple is true
          items = item.parents(".item").find("[data-key=#{id}] option:selected")
          values[id] = []
          for box in items
            values[id].push( $(box).val() )
        else
          values[id] = item.parents(".item").find("[data-key=#{id}] option:selected").val()
      if (type is "checkbox")
        if item.is(":checked")
          if (!values[id]?) then values[id] = []
          values[id].push( item.val() )

    # Fill in empty results and
    # chop off the defaults.
    for item in keys
      item = $(item)
      id = item.data("key")
      required = item.parent().data("required") is "required"
      val = values[id]
      if !val? || val == "-" || val == ""
        values[id] = undefined
      if (required is true and (!values[id]? or values[id] is ""))
        errors.push(id)

    return [values, errors]