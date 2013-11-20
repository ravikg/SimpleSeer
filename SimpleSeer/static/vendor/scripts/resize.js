$(function() {
  $(document).on('mousedown', '.resize', function(e){
    e.preventDefault();
    $(document).mousemove(function(b){

      $(e.target).closest('.resizable').attr('data-state', 'open')
      
      if($(e.target).data('handle') == "e" || $(e.target).data('handle') == "w"){
        $(e.target).closest('.resizable').css("width",b.pageX);
      } else if($(e.target).data('handle') == "n" || $(e.target).data('handle') == "s"){
        $(e.target).closest('.resizable').css("height",b.pageY);
      }

      $(e.target).closest('.container').find('.reciprocate').css('left', $(e.target).closest('.resizable').width() + 1)

    })
  });
  $(document).on('mouseup', 'body', function(e){
    $(document).unbind('mousemove');
  });
});
