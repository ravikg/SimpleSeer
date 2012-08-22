lib = require '../Highcharts'

module.exports = class line extends lib
  
  initialize: (d) =>
    super d
    @lib = 'highcharts'
    return @
