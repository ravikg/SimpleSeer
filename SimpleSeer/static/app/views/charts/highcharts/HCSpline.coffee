lib = require '../Highcharts'

module.exports = class spline extends lib

  initialize: (d) =>
    super d
    @lib = 'highcharts'
    return @
