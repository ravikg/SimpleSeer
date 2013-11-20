[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/image")
]

module.exports = class Image extends SubView
  template: Template

  getRenderData: =>
    path: "http://image.europeancarweb.com/f/tires/products/epcp_1103_bridgestone_america_new_ultra_high_performance_tires/32457691/epcp-1103-05-o%2Bbridgestone-america-new-ultra-high-performance-tires%2BRE960AS.jpg"

  reflow: =>
    console.log "reflow"