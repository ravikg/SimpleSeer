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
        if o.state
          rs[o.measurement_name] = 'fail'
        else
          rs[o.measurement_name] = 'pass'

      _.each retVal, (o,i) =>

        if rs[o.prop]?
          retVal[i].state = rs[o.prop]

          if retVal[i].state is "fail"
            for mment in SimpleSeer.measurements.models
              if mment.get("name") is retVal[i].prop
                values = []
                tolerance_list = mment.get("tolerance_list")
                if tolerance_list
                  units = mment.get("units")
                  label = ""
                  tol = ""
                  wrap = if units is "deg" then "&deg;" else ""
                  unit = mment.get("units").replace("deg", "")
                  val = Number(retVal[i].value)
                  for tol in tolerance_list
                    if tol.get?
                      if tol.get("criteria")["Part Number"] is "all" or tol.get("criteria")["Part Number"] is @model.get("metadata")["Part Number"]
                        values.push tol.get("rule")
                  values.sort()

                if values is true
                  _.each values, (o, i) =>
                    if o.operator == "<" and val > o.value
                      label = "Max";
                      tol = "#{o.value}"
                    if o.operator == ">" and val < o.value
                      label = "Min";
                      tol = "#{o.value}"

                  retVal[i].tolerances = {label: label, value: tol + unit + wrap}
                break
                
    return {features: retVal, count: retVal.length}

