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
      if tag is "INPUT"
        type = item.attr("type")
      if (type is "text" or item.type is "password")
        values[id] = item.val()
      if (type is "textarea")
        values[id] = item.html()
      if (type is "radio")
        values[id] = item.parent().find("[data-key=#{id}]:checked").val()
      if (type is "select")
        if item.multiple is true
          items = item.parent().find("[data-key=#{id}] option:selected")
          values[id] = []
          for box in items
            values[id].push $(box).val()
        else
          values[id] = item.parent().find("[data-key=#{id}] option:selected").val()
      if (type is "checkbox")
        items = item.parent().find("[data-key=#{id}]:checked")
        values[id] = []
        for box in items
          values[id].push $(box).val()
      if (required is true and (!values[id]? or values[id] is ""))
        errors.push id
    return [values, errors]