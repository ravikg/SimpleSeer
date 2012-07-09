#/* @pjs font="/font/arial.ttf"; */
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
    [@feature.get("x"), @feature.get("y"), @feature.get("featuredata").head_width_inch.toPrecision(3),@feature.get("featuredata").shaft_width_inch.toPrecision(3), @feature.get("featuredata").lbs_width_inch.toPrecision(3),@feature.get("featuredata").lbs_left_angle.toPrecision(4), @feature.get("featuredata").lbs_right_angle.toPrecision(4)]



        
  dropshadow = (pjs,pt1,pt2,color,txt) ->
    arrow_sz = 10
    end_line = 25
    ds = 5
    pjs.fill(color[0],color[1],color[2]) 
    pjs.stroke 0,0,0,128
    pjs.line(pt1[0],pt1[1]+ds,pt2[0],pt2[1]+ds)
    pjs.line(pt1[0]-ds,pt1[1]+end_line,pt1[0]-ds,pt1[1]-end_line)
    pjs.line(pt2[0]+ds,pt2[1]+end_line,pt2[0]+ds,pt2[1]-end_line)
    pjs.triangle(pt1[0]-ds,pt1[1]+ds,pt1[0]-arrow_sz-ds,pt1[1]+arrow_sz+ds,pt1[0]-arrow_sz-ds,pt1[1]-arrow_sz+ds)
    pjs.triangle(pt2[0]+ds,pt2[1]+ds,pt2[0]+arrow_sz+ds,pt2[1]+arrow_sz+ds,pt2[0]+arrow_sz+ds,pt2[1]-arrow_sz+ds) 
    # Do a drop shaddow
    pjs.stroke color[0], color[1], color[2], 255
    pjs.line(pt1[0],pt1[1],pt2[0],pt2[1])
    pjs.line(pt1[0],pt1[1]+end_line,pt1[0],pt1[1]-end_line)
    pjs.line(pt2[0],pt2[1]+end_line,pt2[0],pt2[1]-end_line)
   
    pjs.triangle(pt1[0],pt1[1],pt1[0]-arrow_sz,pt1[1]+arrow_sz,pt1[0]-arrow_sz,pt1[1]-arrow_sz)
    pjs.triangle(pt2[0],pt2[1],pt2[0]+arrow_sz,pt2[1]+arrow_sz,pt2[0]+arrow_sz,pt2[1]-arrow_sz)
     
    tw = pjs.textWidth(txt)
    xtxt = ((pt2[0]-pt1[0])/2)+pt1[0]-(tw/2)
    pjs.fill(0,0,0,128)
#    pjs.stroke 255,0,0,255
    pjs.text(txt,xtxt,pt1[1]-40)
    pjs.fill(255,255,255,255)
#    pjs.stroke 0,0,0,128
    pjs.text(txt,xtxt-3,pt1[1]-40-3)
    pjs.noFill()  
            
  render: (pjs) =>
 
    pjs.textFont(pjs.createFont("arial",32))
    pjs.stroke 180, 0, 180, 128              
    pjs.strokeWeight 5
    pjs.noFill()
    ds = 5

    arrow_sz = 10
    end_line = 25
    # HEAD LINE
    x0 = @feature.get("featuredata").head_line[0][0]
    y0 = @feature.get("featuredata").head_line[0][1]
    x1 = @feature.get("featuredata").head_line[1][0]
    y1 = @feature.get("featuredata").head_line[1][1]
    String temp = @feature.get("featuredata").head_width_inch.toPrecision(3).toString() + " in."
    dropshadow(pjs,[x0,y0],[x1,y1],[180,180,0],temp )
    
    x0 = @feature.get("featuredata").shaft_line[0][0]
    y0 = @feature.get("featuredata").shaft_line[0][1]
    x1 = @feature.get("featuredata").shaft_line[1][0]
    y1 = @feature.get("featuredata").shaft_line[1][1]
    temp = @feature.get("featuredata").shaft_width_inch.toPrecision(3).toString() + " in."
    dropshadow(pjs,[x0,y0],[x1,y1],[180,180,0],temp )

    shift = -60
    x0 = @feature.get("featuredata").lbs_line[0][0]
    y0 = @feature.get("featuredata").lbs_line[0][1]+shift
    x1 = @feature.get("featuredata").lbs_line[1][0]
    y1 = @feature.get("featuredata").lbs_line[1][1]+shift
    temp = @feature.get("featuredata").lbs_width_inch.toPrecision(3).toString() + " in." 
    dropshadow(pjs,[x0,y0],[x1,y1],[180,180,0],temp)

    pjs.stroke 180, 180, 0, 255
    fsz = 100
    p = 3.1415962
    offset = 60
    x0 = @feature.get("featuredata").fillet_left[0]
    y0 = @feature.get("featuredata").fillet_left[1]
    r0 = @feature.get("featuredata").fillet_left_r
    pjs.ellipse(x0,y0,2*r0,2*r0)

    x0 = x0-offset
    y0 = y0+offset

    pjs.line(x0,y0,x0-fsz,y0)
    pjs.line(x0,y0,x0,y0+fsz)
    pjs.arc(x0,y0,fsz,fsz,p/2,p)

    txt=@feature.get("featuredata").lbs_left_angle.toPrecision(4).toString()
    tw = pjs.textWidth(txt)
    xtxt = (x0-(fsz/2))-(tw/2)
    ytxt = (y0+fsz-20)
    pjs.fill(255,255,255,255)
    pjs.text(txt,xtxt,ytxt)
    pjs.noFill()  


    
 
    x0 = @feature.get("featuredata").fillet_right[0]
    y0 = @feature.get("featuredata").fillet_right[1]
    r0 = @feature.get("featuredata").fillet_right_r
    pjs.ellipse(x0,y0,2*r0,2*r0)
    x0 = x0+offset
    y0 = y0+offset
    pjs.line(x0,y0,x0+fsz,y0)
    pjs.line(x0,y0,x0,y0+fsz)
    pjs.arc(x0,y0,fsz,fsz,0,p/2)

    txt=@feature.get("featuredata").lbs_right_angle.toPrecision(4).toString()
    tw = pjs.textWidth(txt)
    xtxt = (x0+(fsz/2))-(tw/2)
    ytxt = (y0+fsz-20)
    pjs.fill(255,255,255,255)
    pjs.text(txt,xtxt,ytxt)
    pjs.noFill()  
                   



#<Name of the python class we map to>:<the class upstairs>
plugin this, FastenerFeature:FastenerFeature
