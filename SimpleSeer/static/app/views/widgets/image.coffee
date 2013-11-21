[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/image")
]

module.exports = class Image extends SubView
  template: Template

  getRenderData: =>
    thumbnail_path: "http://image.europeancarweb.com/f/tires/products/epcp_1103_bridgestone_america_new_ultra_high_performance_tires/32457691/epcp-1103-05-o%2Bbridgestone-america-new-ultra-high-performance-tires%2BRE960AS.jpg"
    image_path: "http://image.europeancarweb.com/f/tires/products/epcp_1103_bridgestone_america_new_ultra_high_performance_tires/32457691/epcp-1103-05-o%2Bbridgestone-america-new-ultra-high-performance-tires%2BRE960AS.jpg"

  reflow: =>
    outer = $(@$el.get(0))
    inner = @$el.find('img')
    console.log 'OUTER:', 'w', outer.width(), 'h', outer.height(), 'offset', outer.offset()
    console.log 'IMG:', 'w', inner.width(), 'h', inner.height()


  afterRender: =>
    console.log "After render"