[Template, SubView, application] = [
  require("views/widgets/templates/key"),
  require("views/core/subview"),
  require("application")
]

module.exports = class Key extends SubView
  template: Template
  className: 'menu-widget key-widget'

  setModel:(model) =>
    @model = model
    @render()

  render:=>
    if @options.parent.active
      return super()

  getRenderData:=>
    retVal = []
    if @model
      for i,o of @model.get('features')
        md = o[0].metadata()
        for k,v of md
          retVal.push v

      rs = {}
      for i,o of @model.get('results')
        rs[o.measurement_name] = {}
        if o.state
          rs[o.measurement_name]['state'] = 'fail'
          if o.tolerance_object
            rs[o.measurement_name]['values'] = o.tolerance_object
        else
          rs[o.measurement_name]['state'] = 'pass'

      _.each retVal, (o,i) =>

        if rs[o.prop]?
          retVal[i].state = rs[o.prop].state

          if retVal[i].state is "fail"

            for mment in SimpleSeer.measurements.models
              if mment.get("name") is retVal[i].prop
                units = mment.get("units")
                label = ""
                tol = 
                wrap = if units is "deg" then "&deg;" else ""
                unit = mment.get("units").replace("deg", "")
                val = Number(retVal[i].value)

                if rs[o.prop].values
                  v = rs[o.prop]['values']
                  if v.operator == "<" and val > v.value
                    label = "Max"
                    tol = "#{v.value}"
                  if v.operator == ">" and val < v.value
                    label = "Min"
                    tol = "#{v.value}"

                  retVal[i].tolerances = {label: label, value: tol + unit + wrap}
                break
                
    return {features: retVal, count: retVal.length}

