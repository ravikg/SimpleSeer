View = require "views/core/view"

module.exports = class Feature extends View
  scale: 1
  stroke: 1
  font_size: 20
  arrow_size: 8
  spacing: 8

  addTrait: (trait) =>
    #@data[trait.measurement_name] = trait.numeric
    @attributes[trait.measurement_name] = trait.numeric

  represent: =>
    plugin = @getPluginMethod(@.get("featuretype"), 'represent')
    if plugin?
      return plugin()
    @.get("featuretype") + " at (" + @.get("x") + "," + @.get("y") + ")"

  tableOk: =>
    plugin = @getPluginMethod(@.get("featuretype"), 'tableOk')
    if plugin?
      return plugin()

  tableHeader: =>
    plugin = @getPluginMethod(@.get("featuretype"), 'tableHeader')
    if plugin?
      return plugin()

  tableData: =>
    plugin = @getPluginMethod(@.get("featuretype"), 'tableData')
    if plugin?
      return plugin()

  name: =>
    plugin = @getPluginMethod(@.get("featuretype"), 'name')
    if plugin?
      return plugin()
    return @.get("featuretype").replace("Feature","")

  plural: =>
    plugin = @getPluginMethod(@.get("featuretype"), 'plural')
    if plugin?
      return plugin()
    return @name() + "s"

  icon: =>
    plugin = @getPluginMethod(@.get("featuretype"), 'icon')
    if plugin?
      return plugin()
    return ""

  render: (pjs) =>
    plugin = @getPluginMethod(@.get("featuretype"), 'render')
    if plugin?
      return plugin(pjs)
    pjs.stroke 0, 180, 180
    pjs.strokeWeight 3
    pjs.noFill()
    pjs.rect @.get('x')-@.get('width')/2,@.get('y')-@.get('height')/2,@.get('width'),@.get('height')

  # The following code is to aid in actual markup of
  # the features. All helpers should respect the
  # @scale property.

  angleOnCircle:(p2, p1) =>
    angle = Math.atan2((p1.y - p2.y), (p2.x - p1.x))
    if angle < 0 then return @deg2rad(360) + angle
    return angle

  rad2deg:(rad) =>
    return rad * 180 / Math.PI

  deg2rad:(deg) =>
    return Math.PI * deg / 180

  label:(pjs, xy, label, mock=false) =>
    [x, y] = xy
    pjs.noFill()
    pjs.strokeWeight(@stroke)
    pjs.rectMode(pjs.CORNER)
    pjs.strokeJoin(pjs.MITER)
    pjs.textAlign(pjs.CENTER, pjs.TOP)
    pjs.textFont(pjs.createFont("courier new", @font_size * @scale))
    margin = @stroke * 5
    labelW = pjs.textWidth label
    totalW = (@stroke * 2) + (margin * 2) + labelW
    totalH = (@stroke * 2) + (margin * 2) + (@font_size * @scale) - (2 * @scale)
    unless mock is true
      pjs.strokeWeight(@stroke * @scale)
      pjs.rect(x, y, totalW, totalH)
      pjs.text(label, x + totalW / 2, y + margin)
    return {width: totalW, height: totalH}

  keyValueBox:(pjs, xy, key, value, alignment="center", mock=false) =>
    [x, y] = xy
    spacing = (@stroke * 5 * @scale)
    l1Mock = @label(pjs, [0, 0], key, true)
    l2Mock = @label(pjs, [0, 0], value, true)
    totalW = l1Mock.width + spacing + l2Mock.width
    totalH = l1Mock.height
    unless mock is true
      if alignment is "gap"
        l1 = @label(pjs, [x - l1Mock.width - (spacing / 2), y], key)
        l2 = @label(pjs, [x + (spacing / 2), y], value)
      if alignment is "center"
        leftEdge = x - totalW / 2
        l1 = @label(pjs, [leftEdge, y], key)
        l2 = @label(pjs, [leftEdge + l1Mock.width + spacing, y], value)
      if alignment is "left"
        l1 = @label(pjs, [x, y], key)
        l2 = @label(pjs, [x + l1Mock.width + spacing, y], value)
    return {width: totalW, height: totalH}

  mockKeyValueBox:(pjs, key, value) =>
    return @keyValueBox(pjs, [0, 0], key, value, "", true)

  arrow:(pjs, xy1, xy2, justHead=false) =>
    if justHead is true
      [a, b] = xy1
      angle = @deg2rad(xy2)
      [c, d] = [
        a + @arrow_size * @scale * pjs.cos(angle - @deg2rad(30)),
        b + @arrow_size * @scale * pjs.sin(angle - @deg2rad(30)) ]
      [e, f] = [
        a + @arrow_size * @scale * pjs.cos(angle + @deg2rad(30)),
        b + @arrow_size * @scale * pjs.sin(angle + @deg2rad(30)) ]
      pjs.triangle(a, b, c, d, e, f)
    else
      [x, y] = xy2; [a, b] = xy1
      angle = @deg2rad(360) - @angleOnCircle({x: x, y: y}, {x: a, y: b})
      [c, d] = [
        a + @arrow_size * @scale * pjs.cos(angle - @deg2rad(30)),
        b + @arrow_size * @scale * pjs.sin(angle - @deg2rad(30)) ]
      [e, f] = [
        a + @arrow_size * @scale * pjs.cos(angle + @deg2rad(30)),
        b + @arrow_size * @scale * pjs.sin(angle + @deg2rad(30)) ]
      pjs.strokeWeight(@stroke * @scale)
      pjs.triangle(a, b, c, d, e, f)
      pjs.line(a, b, x, y)

  anglePlatform:(pjs, xy, angle_width, angle_height=29*@scale) =>
    [x0, y0] = xy
    x1 = x0 + angle_width
    y1 = y0
    pjs.strokeWeight(@stroke * @scale)
    pjs.line(x0, y0, x1, y1)
    pjs.line(x0, y0 + angle_height, x1, y1)
    pjs.noFill()
    pjs.arc(x1, y1, angle_width, angle_width, pjs.PI - 0.25, pjs.PI)

  distancePlatform:(pjs, p1, p2, style, color, key, val, align="center") =>
    p1 = _.clone p1
    p2 = _.clone p2
    kv = @mockKeyValueBox(pjs, key, val)
    if p1[1] != p2[1] and p1[0] != p2[0]
      d0 = p2[0] - p1[0]
      d1 = p2[1] - p1[1]
      if (d0 > d1) then (p2[1] = p1[1]) else (p2[0] = p1[0])
    pjs.strokeWeight(@stroke * @scale)
    if p1[1] is p2[1]
      if align is "center"
        lineWidth = p2[0] - p1[0]
        pjs.fill(color[0],color[1],color[2])
        pjs.stroke(color[0], color[1], color[2])
        @keyValueBox(pjs, [p1[0] + lineWidth / 2, p1[1] - kv.height / 2 + style[1]], key, val, "center")
        pjs.fill(color[0],color[1],color[2])
        pjs.stroke(color[0], color[1], color[2])
        @arrow(pjs, [p1[0], p1[1] + style[1]], [p1[0] + lineWidth / 2 - kv.width / 2, p1[1] + style[1]])
        @arrow(pjs, [p2[0], p2[1] + style[1]], [p1[0] + lineWidth / 2 + kv.width / 2, p1[1] + style[1]])
      if align is "left"
        lineWidth = p2[0] - p1[0]
        pjs.fill(color[0],color[1],color[2])
        pjs.stroke(color[0], color[1], color[2])
        @keyValueBox(pjs, [p1[0] + 30 * @scale, p1[1] - kv.height  / 2 + style[1]], key, val, "left")
        pjs.fill(color[0],color[1],color[2])
        pjs.stroke(color[0], color[1], color[2])
        @arrow(pjs, [p1[0], p1[1] + style[1]], [p1[0] + 30 * @scale, p1[1] + style[1]])
        @arrow(pjs, [p2[0], p2[1] + style[1]], [p1[0] + 30 * @scale + kv.width, p1[1] + style[1]])
      if align is "right"
        lineWidth = p2[0] - p1[0]
        pjs.fill(color[0],color[1],color[2])
        pjs.stroke(color[0], color[1], color[2])
        @keyValueBox(pjs, [p2[0] - 30 * @scale - kv.width, p1[1] - kv.height  / 2 + style[1]], key, val, "left")
        pjs.fill(color[0],color[1],color[2])
        pjs.stroke(color[0], color[1], color[2])
        @arrow(pjs, [p1[0], p1[1] + style[1]], [p2[0] - 30 * @scale - kv.width, p1[1] + style[1]])
        @arrow(pjs, [p2[0], p1[1] + style[1]], [p2[0] - 30 * @scale, p1[1] + style[1]])

      if style[1] is 0
        pjs.line(p1[0], p1[1] - @spacing * @scale, p1[0], p1[1] + @spacing * @scale)
        pjs.line(p2[0], p2[1] - @spacing * @scale, p2[0], p2[1] + @spacing * @scale)
      else if style[1] > 0
        pjs.line(p1[0], p1[1], p1[0], p1[1] + style[1])
        pjs.line(p2[0], p2[1], p2[0], p2[1] + style[1])
      else
        pjs.line(p1[0], p1[1] + style[1], p1[0], p1[1])
        pjs.line(p2[0], p2[1] + style[1], p2[0], p2[1])

  boundingBox: (pjs, bb, offset=0, position, color, id, label) =>
    bb = _.clone bb
    pjs.fill(color[0],color[1],color[2])
    pjs.stroke(color[0], color[1], color[2])
    pt1 = [(bb[0][0] + bb[1][0]) / 2, (bb[0][1] + bb[1][1]) / 2]
    pt2 = [(bb[2][0] + bb[3][0]) / 2, (bb[2][1] + bb[3][1]) / 2]
    pjs.line(bb[0][0], bb[0][1], bb[1][0], bb[1][1])
    kv = @mockKeyValueBox(pjs, id, label)
    pjs.fill(color[0],color[1],color[2])
    pjs.strokeWeight(@stroke * @scale)
    unless offset is 0
      pjs.line(pt1[0], pt1[1], pt1[0] + offset, pt1[1])
      pjs.line(pt2[0], pt2[1], pt2[0] + offset, pt2[1])
      pt1[0] += offset
      pt2[0] += offset
    if position is "top"
      @arrow(pjs, pt1, [pt1[0], pt1[1] - kv.height - 12 * @scale])
      @arrow(pjs, pt2, [pt2[0], pt2[1] + 20 * @scale])
      @keyValueBox(pjs, [pt1[0], pt1[1] - kv.height - 12 * @scale], id, label, "gap")
    if position is "bottom"
      @arrow(pjs, pt1, [pt1[0], pt1[1] - 20 * @scale])
      @arrow(pjs, pt2, [pt2[0], pt2[1] + kv.height + 12 * @scale])
      @keyValueBox(pjs, [pt1[0], pt2[1] + 11 * @scale], id, label, "gap")

  arrowBox: (pjs, lined, offset=0, position, color, id, label) =>
    pjs.fill(color[0],color[1],color[2])
    pjs.strokeWeight(@stroke * @scale)
    pjs.stroke(color[0], color[1], color[2])
    p1 = [parseInt(lined[0][0], 10), parseInt(lined[0][1], 10)]
    p2 = [parseInt(lined[1][0], 10), parseInt(lined[1][1], 10)]
    kv = @mockKeyValueBox(pjs, id, label)
    pjs.strokeWeight(@stroke * @scale)
    pjs.fill(color[0],color[1],color[2])
    unless offset is 0
      pjs.line(p1[0], p1[1], p1[0] + offset, p1[1])
      pjs.line(p2[0], p2[1], p2[0] + offset, p2[1])
      p1[0] = p1[0] + offset
      p2[0] = p2[0] + offset
    if position is "top"
      @arrow(pjs, p1, [p1[0], p1[1] - kv.height - 12 * @scale])
      @arrow(pjs, p2, [p2[0], p2[1] + 20 * @scale])
      @keyValueBox(pjs, [p1[0] - 1, p1[1] - kv.height - 12 * @scale], id, label, "gap")
    if position is "bottom"
      @arrow(pjs, p1, [p1[0], p1[1] - 20 * @scale])
      @arrow(pjs, p2, [p2[0], p2[1] + kv.height + 12 * @scale])
      @keyValueBox(pjs, [p1[0] - 1, p2[1] + 11 * @scale], id, label, "gap")
