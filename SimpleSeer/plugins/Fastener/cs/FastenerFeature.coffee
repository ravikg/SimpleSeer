class FastenerFeature
  constructor: (feature) ->
    @feature = feature
   
  
  icon: () => "/img/template.png" 
    
  represent: () =>
    "Fastener Detected at (" + @feature.get("x") + ", " + @feature.get("y") + ") shaft width" + @feature.get("featuredata").shaft_width_inch + " inches and a head width of " + @feature.get("featuredata").head_width_inch + "."
            
  tableOk: => true
    
  tableHeader: () =>
    ["X Positon", "Y Position", "Head Width (in)", "Shaft Width (in)", "LBS Diameter (in)","Left Fillet Angle","Right Fillet Angle" ]
    
  tableData: () =>
    [@feature.get("x"), @feature.get("y"), @feature.get("featuredata").head_width_inch,@feature.get("featuredata").shaft_width_inch, @feature.get("featuredata").lbs_width_inch,@feature.get("featuredata").lbs_left_angle, @feature.get("featuredata").lbs_right_angle]
    
  render: (pjs) =>
    pjs.stroke 180, 0, 180
    pjs.strokeWeight 3
    pjs.noFill()
    pjs.line(10,10,300,300)
    # x0 = @feature.get("featuredata").head_line[0][0]
    # y0 = @feature.get("featuredata").head_line[0][1]
    # x1 = @feature.get("featuredata").head_line[1][0]
    # y1 = @feature.get("featuredata").head_line[1][1]
    # x0 = @feature.get('x')
    # y0 = @feature.get('y')
    # pjs.line(x0,y0,x1,y1)
    # pjs.line(x0,y0-10,x1,y1-10)
    # pjs.line(x0,y0+10,x1,y1+10)
    # pjs.triangle(x0,y0,x0+5,y0+5,x0-5,y0-5)
    # pjs.triangle(x1,y1,x1+5,y1+5,x1-5,y1-5) 
    # PFont fontA = loadFont("Arial")
    # textFont(fontA, 32)
    # x = 30
    # y = 40
    # #fill(0);
    # text("ichi", x, 60);   

#<Name of the python class we map to>:<the class upstairs>
plugin this, FastenerFeature:FastenerFeature
