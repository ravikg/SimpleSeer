[Application, 
 Table] = [
  require('application'),
  require('views/table')
]

module.exports = class DataTable extends Table

  # Takes in a collection of data returns that same collection
  # But with a new field in attributes called "formatted" which
  # is an object with {value:value, classes:classes}
  _formatData: (data) =>
    data = super(data)

    for o,i in data
      for y,x in @settings.columns
        if y.data?.key
          location = y.data.key.split('.')

          if !o.attributes.formatted
            o.attributes.formatted = {}
          if !o.attributes.formatted[y.data.key]
            o.attributes.formatted[y.data.key] = {value:'', classes:[]}
              
          if location[0] is 'capturetime_epoch' # Handles capturetime
            o.attributes.formatted[y.data.key].value = moment(o.get(location[0])).format('MM/DD/YYYY HH:mm')

          if location.length > 1
            if location[0] is 'metadata' # Handles all columns in metadata
              d = o.get(location[0])[location[1]]
              if !d
                d = ''
              o.attributes.formatted[y.data.key].value = d
            else if location[1] is 'numeric' # Handles all results that are numeric
              for b,a in o.attributes.results
                plugin = Application.measurements.where({name:b.measurement_name})[0]
                if b.measurement_name is location[0]
                  o.attributes.formatted[y.data.key].value = (if b.numeric then b.numeric.toFixed(plugin.get('fixdig')) else '')
                  if b.state
                    o.attributes.formatted[y.data.key].classes.push('fail')
          if y.href
            href = y.href
            pattern = /\#\{([\w\.\_]+)\}/g
            for placeholder in y.href.match(pattern)
              path = placeholder.slice(2, -1)
              if path is "this"
                val = o.attributes.formatted[y.data.key].value
              else
                val = o.get(path)
              href = href.replace(placeholder, val)
            o.attributes.formatted[y.data.key].href = href

    return data

  # Append some settings to our table settings dict
  _settings: =>
    settings = super()
    settings.styles.push('margin-top: 35px;')
    settings.toggles = true
    settings.hideEmpty = true
    return settings

  # Append some variables to our table variables dict
  _variables: =>
    variables = super()
    variables.preHTML = '<div class="preheader">
              <div class="toggles"></div>
              <div class="downloads">
                <button class="special" data-type="csv">
                  <div class="badge download"> </div>
                  CSV
                </button>
                <button class="special" data-type="excel">
                  <div class="badge download"> </div>
                  Excel (.xls)
                </button>
              </div>
            </div>' + variables.preHTML
    return variables