class FastenerFeature
  constructor: (feature) ->
    @feature = feature
   
  
  icon: () => "/img/template.png" 
    
  represent: () =>
    "Fastener Detected at (" + @feature.get("x") + ", " + @feature.get("y") + ")."
 
  tableOk: => true
    
  tableHeader: () =>
    ["X Positon", "Y Position", "Head Width (in)", "Shaft Width (in)", "LBS Diameter (in)","Left Fillet Angle","Right Fillet Angle" ]
    
  tableData: () =>
    [@feature.get("x"), @feature.get("y"), @feature.get("featuredata").head_width_inch,@feature.get("featuredata").shaft_width_inch, @feature.get("featuredata").lbs_width_inch,@feature.get("featuredata").lbs_left_angle, @feature.get("featuredata").lbs_right_angle]
    
  render: (pjs) =>
    pjs.stroke 180, 0, 180, 128
    pjs.strokeWeight 5
    pjs.noFill()
    arrow_sz = 10
    end_line = 25
    x0 = @feature.get("featuredata").head_line[0][0]
    y0 = @feature.get("featuredata").head_line[0][1]
    x1 = @feature.get("featuredata").head_line[1][0]
    y1 = @feature.get("featuredata").head_line[1][1]
    pjs.line(x0,y0,x1,y1)
    pjs.line(x0,y0+end_line,x0,y0-end_line)
    pjs.line(x1,y1+end_line,x1,y1-end_line)
    pjs.triangle(x0,y0,x0-arrow_sz,y0+arrow_sz,x0-arrow_sz,y0-arrow_sz)
    pjs.triangle(x1,y1,x1+arrow_sz,y1+arrow_sz,x1+arrow_sz,y1-arrow_sz) 

    pjs.stroke 180, 90, 0, 128
    x0 = @feature.get("featuredata").shaft_line[0][0]
    y0 = @feature.get("featuredata").shaft_line[0][1]
    x1 = @feature.get("featuredata").shaft_line[1][0]
    y1 = @feature.get("featuredata").shaft_line[1][1]
    pjs.line(x0,y0,x1,y1)
    pjs.line(x0,y0+end_line,x0,y0-end_line)
    pjs.line(x1,y1+end_line,x1,y1-end_line)
    pjs.triangle(x0,y0,x0-arrow_sz,y0+arrow_sz,x0-arrow_sz,y0-arrow_sz)
    pjs.triangle(x1,y1,x1+arrow_sz,y1+arrow_sz,x1+arrow_sz,y1-arrow_sz) 


    # we're going to shift this line down so we can see
    # the LBS
    pjs.stroke 0, 180, 180, 128
    shift = 150
    x0 = @feature.get("featuredata").lbs_line[0][0]
    y0 = @feature.get("featuredata").lbs_line[0][1]+shift
    x1 = @feature.get("featuredata").lbs_line[1][0]
    y1 = @feature.get("featuredata").lbs_line[1][1]+shift
    pjs.line(x0,y0,x1,y1)
    pjs.line(x0,y0+end_line,x0,y0-end_line-shift)
    pjs.line(x1,y1+end_line,x1,y1-end_line-shift)
    pjs.triangle(x0,y0,x0-arrow_sz,y0+arrow_sz,x0-arrow_sz,y0-arrow_sz)
    pjs.triangle(x1,y1,x1+arrow_sz,y1+arrow_sz,x1+arrow_sz,y1-arrow_sz) 

    pjs.stroke 180, 180, 0, 128
    fsz = 100
    p = 3.1415962
    x0 = @feature.get("featuredata").fillet_left[0]
    y0 = @feature.get("featuredata").fillet_left[1]
    pjs.line(x0,y0,x0-fsz,y0)
    pjs.line(x0,y0,x0,y0+fsz)
    pjs.arc(x0,y0,fsz,fsz,p/2,p)
 
    x0 = @feature.get("featuredata").fillet_right[0]
    y0 = @feature.get("featuredata").fillet_right[1]
    pjs.line(x0,y0,x0+fsz,y0)
    pjs.line(x0,y0,x0,y0+fsz)
    pjs.arc(x0,y0,fsz,fsz,0,p/2)
#    String[] fontList = pjs.PFont.list();
#    pjs.println(fontList);
    # pjs.PFont fontA = pjs.loadFont("Arial")
    # pjs.textFont(fontA, 32)
    # x = 30
    # y = 40
    # pjs.fill(0);
    # pjs.text("ichi", x, 60);
           

#<Name of the python class we map to>:<the class upstairs>
plugin this, FastenerFeature:FastenerFeature
