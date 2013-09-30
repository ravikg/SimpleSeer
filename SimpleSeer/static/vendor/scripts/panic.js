window.PanicMode = function(visible) {
    if(visible === false) {
        $("#panic").remove();
    } else {
        $("<div id='panic'><p>Error! Please Contact System Administrator</p></div>").appendTo(document.body);
    }
}