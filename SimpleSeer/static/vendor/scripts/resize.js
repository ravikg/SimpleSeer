$(function() {
  $(document).on('mousedown', '.resize', function(e){
    e.preventDefault();
    $(document).mousemove(function(b){
      if($(e.target).data('handle') == "e" || $(e.target).data('handle') == "w"){
        $(e.target).closest('.resizable').css("width",b.pageX);
      } else if($(e.target).data('handle') == "n" || $(e.target).data('handle') == "s"){
        $(e.target).closest('.resizable').css("height",b.pageY);
      } 
    })
  });
  $(document).on('mouseup', 'body', function(e){
    $(document).unbind('mousemove');
  });
});