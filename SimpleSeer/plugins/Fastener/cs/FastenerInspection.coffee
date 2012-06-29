class Fastener
  constructor: (inspection) ->
    @inspection = inspection
  represent: () =>
    "Fastener Detection"
# LHS - The setup ini file inspection name
# RHS - The name of this coffee script class
plugin this, fastener:Fastener
