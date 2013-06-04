#application = require '../application'

module.exports = class Palette
  currentScheme: "prime"

  hsvToRgb = (h, s, v) ->
    r = undefined
    g = undefined
    b = undefined
    i = undefined
    f = undefined
    p = undefined
    q = undefined
    t = undefined
    
    # Make sure our arguments stay in-range
    h = Math.max(0, Math.min(360, h))
    s = Math.max(0, Math.min(100, s))
    v = Math.max(0, Math.min(100, v))
    
    # We accept saturation and value arguments from 0 to 100 because that's
    # how Photoshop represents those values. Internally, however, the
    # saturation and value are calculated from a range of 0 to 1. We make
    # That conversion here.
    s /= 100
    v /= 100
    if s is 0
      
      # Achromatic (grey)
      r = g = b = v
      return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)]
    h /= 60 # sector 0 to 5
    i = Math.floor(h)
    f = h - i # factorial part of h
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    switch i
      when 0
        r = v
        g = t
        b = p
      when 1
        r = q
        g = v
        b = p
      when 2
        r = p
        g = v
        b = t
      when 3
        r = p
        g = q
        b = v
      when 4
        r = t
        g = p
        b = v
      else # case 5:
        r = v
        g = p
        b = q
    [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)]

  componentToHex = (c) ->
    hex = c.toString(16)
    (if hex.length is 1 then "0" + hex else hex)

  rgbToHex = (r, g, b) ->
    "#" + componentToHex(r) + componentToHex(g) + componentToHex(b)

  # palette = require("lib/ui_helper")
  # p = new palette
  # p.generate(colors, variations, list[{'h':int(0-360)}, ...])
  # hsvs = p.generate(1, 1, [{'h':null}, {'h':60}, {'h':20}])
  # > [[{h:360, s:100, v:100, r:255, g:0, b:0, hex: "#FF0000"}, {...}, ...], [...], ...]

  generate: (cols, vars, h = []) =>
    hsvs = []
    iH = 360
    iHint = 360/cols
    iS = 100
    iV = 100
    iVint = 100/vars

    i = 0
    while i < cols
      if !hsvs[i]
        hsvs[i] = []

      j = 0
      while j < vars
        if !hsvs[i][j]
          hsvs[i][j] = {}

        # Set H
        if h[i]?['h']
          hsvs[i][j]['h'] = h[i]['h']
        else if i == 0
          hsvs[i][j]['h'] = 360
        else
          hsvs[i][j]['h'] = 360 - (i * iHint)

        # Set S
        hsvs[i][j]['s'] = 100

        # Set V
        if j == 0
          hsvs[i][j]['v'] = 100
        else
          hsvs[i][j]['v'] = 100 - (j * iVint)

        # Set RGB
        if hsvs[i][j]['h']? and hsvs[i][j]['s']? and hsvs[i][j]['v']?
          rgb = hsvToRgb(hsvs[i][j]['h'], hsvs[i][j]['s'], hsvs[i][j]['v'])

        if rgb[0]? and rgb[1]? and rgb[2]?
          hsvs[i][j]['r'] = rgb[0]
          hsvs[i][j]['g'] = rgb[1]
          hsvs[i][j]['b'] = rgb[2]

        # Set Hex
        if hsvs[i][j]['r']? and hsvs[i][j]['g']? and hsvs[i][j]['b']?
          hex = rgbToHex(hsvs[i][j]['r'], hsvs[i][j]['g'], hsvs[i][j]['b'])

        if hex?
          hsvs[i][j]['hex'] = hex

        j++

      i++

    return hsvs

  
  schemes:
    prime:
      title: "Primary Colors"
      colors:
        black: {default: 0, shades: ["#404547"]}
        red: {default: 0, shades: ["#D81313"]}
        orange: {default: 0, shades: ["#F97C15"]}
        yellow: {default: 0, shades: ["#FFC200"]}
        green: {default: 0, shades: ["#D3D800"]}
        cyan: {default: 0, shades: ["#02AA46"]}
        blue: {default: 0, shades: ["#0074B5"]}
        purple: {default: 0, shades: ["#6B0052"]}
        white: {default: 0, shades: ["#968477"]}
          
    basic:
      title: "Basic Colors"
      colors:
        black: {default: 0, shades: ["#111111"]}
        red: {default: 0, shades: ["#ff0000"]}
        orange: {default: 0, shades: ["#ff9000"]}
        yellow: {default: 0, shades: ["#ffff00"]}
        green: {default: 0, shades: ["#00ff00"]}
        cyan: {default: 0, shades: ["#00ffff"]}
        blue: {default: 0, shades: ["#0000ff"]}
        purple: {default: 0, shades: ["#9000ff"]}
        white: {default: 0, shades: ["#ffffff"]}       
      
    dark:
      title: "Dark Colors"
      colors:
        black: {default: 0, shades: ["#111111"]}
        red: {default: 2, shades: ["#C53B3B", "#F80000", "#BA0000", "#F84A4A", "#780000"]}
        orange: {default: 2, shades: ["#FF8859", "#7F2906", "#FF510D", "#7F442C", "#CC420A"]}
        yellow: {default: 2, shades: ["#FFB04C", "#7F4800", "#FF8F00", "#7F5826", "#CC7300"]}
        green: {default: 2, shades: ["#6D902B", "#7FC200", "#507A00", "#93C23A", "#2C4300"]}
        cyan: {default: 2, shades: ["#012340", "#183E4C", "#3D736D", "#8EBF9F", "#E9F2C9"]}
        blue: {default: 2, shades: ["","","#426EA8","",""]}
        purple: {default: 2, shades: ["#423842", "#753F72", "#291628", "#756274", "#C268BD"]}
        white: {default: 0, shades: ["#ffffff"]}
          
    grey:
      title: "Grey Scale"
      colors:
        black: {default: 0, shades: ["#111111"]}
        red: {default: 0, shades: ["#333333"]}
        orange: {default: 0, shades: ["#555555"]}
        yellow: {default: 0, shades: ["#777777"]}
        green: {default: 0, shades: ["#999999"]}
        cyan: {default: 0, shades: ["#bbbbbb"]}
        blue: {default: 0, shades: ["#dddddd"]}
        purple: {default: 0, shades: ["#eeeeee"]}
        white: {default: 0, shades: ["#ffffff"]}             

  getPalette:(scheme = @currentScheme) =>
    colors = []
    for i of @schemes[scheme].colors
      color = @schemes[scheme].colors[i]
      colors.push color.shades[color.default]
    return colors
  
  getPalettes: =>
    palettes = []
    for scheme of @schemes
      colors = []
      for i of @schemes[scheme].colors
        color = @schemes[scheme].colors[i]
        colors.push color.shades[color.default]
      palettes.push colors
    return palettes
  
  getColor:(name) =>
    return @.schemes[@currentScheme].colors[name].shades[@.schemes[@currentScheme].colors[name].default]
  
  getShades:(name) =>
    return @.schemes[@currentScheme].colors[name].shades
  
  getSchemes: =>
    schemes = []
    for i of @schemes
      schemes.push {id: i, title: @schemes[i].title}
    return schemes
  
  getScheme: =>
    return @currentScheme
  
  setScheme: (scheme) =>
    if @schemes[scheme]
      @currentScheme = scheme
    else
      console.error "invalid scheme"
