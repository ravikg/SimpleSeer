window.PanicMode = function(visible) {
    if(visible === false) {
        $("#panic").remove();
    } else {
        $("<div id='panic'><p>Fault!<br>Please contact a System Administrator<br>or Sight Machine technical support</p></div>").appendTo(document.body);
    }
}