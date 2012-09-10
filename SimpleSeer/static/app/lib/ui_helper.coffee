#application = require '../application'

module.exports = class Palette
  currentScheme: "candy"
  
  schemes:
    basic:
      title: "Primary Colors"
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
      
    candy:
      title: "Candy Colors"
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

  getPalette:(scheme = @currentScheme) =>
    colors = []
    for i of @schemes[scheme].colors
      color = @schemes[scheme].colors[i]
      colors.push color.shades[color.default]
    return colors
  
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
