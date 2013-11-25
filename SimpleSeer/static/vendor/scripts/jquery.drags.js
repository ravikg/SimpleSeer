/* http://css-tricks.com/snippets/jquery/draggable-without-jquery-ui/ */
(function($) {
  $.fn.drags = function(opt) {

    opt = $.extend({handle:"",cursor:"move"}, opt);

    if(opt.handle === "") {
      var $el = this;
    } else {
      var $el = this.find(opt.handle);
    }

    return $el.css('cursor', opt.cursor).on("mousedown", function(e) {
      if(opt.handle === "") {
        var $drag = $(this).addClass('draggable');
      } else {
        var $drag = $(this).addClass('active-handle').parent().addClass('draggable');
      }
      var frame = $el.closest('.frame:visible');
      var z_idx = $drag.css('z-index'),
        drg_h = $drag.outerHeight(),
        drg_w = $drag.outerWidth(),
        pos_y = $drag.offset().top + drg_h - e.pageY,
        pos_x = $drag.offset().left + drg_w - e.pageX;
      $drag.css('z-index', 99).on("mousemove", function(e) {
        d_left = $drag.offset().left;
        d_top = $drag.offset().top;
        l = 0;
        t = 0;

        /* Left / Right */
        if(drg_w < frame.outerWidth()) {
          if($drag.offset().left < frame.offset().left) {
            l++;
            d_left = frame.offset().left;
          }
          if( (e.pageX + pos_x - drg_w) < frame.offset().left ) {
            l++;
            d_left = frame.offset().left;
          }
          if($drag.offset().left + drg_w > frame.offset().left + frame.outerWidth()){
            l++;
            d_left = frame.offset().left + frame.outerWidth() - drg_w;
          }
          if( (e.pageX + pos_x - drg_w) + drg_w > frame.offset().left + frame.outerWidth()) {
            l++;
            d_left = frame.offset().left + frame.outerWidth() - drg_w;
          }
        } else {
          if($drag.offset().left > frame.offset().left) {
            l++;
            d_left = frame.offset().left;
          }
          if( (e.pageX + pos_x - drg_w) > frame.offset().left ) {
            l++;
            d_left = frame.offset().left;
          }
          if($drag.offset().left + drg_w < frame.offset().left + frame.outerWidth()){
            l++;
            d_left = frame.offset().left + frame.outerWidth() - drg_w;
          }
          if( (e.pageX + pos_x - drg_w) + drg_w < frame.offset().left + frame.outerWidth()) {
            l++;
            d_left = frame.offset().left + frame.outerWidth() - drg_w;
          }
        }

        /* Up / Down */
        if(drg_h < frame.outerHeight()) {
          if($drag.offset().top < frame.offset().top) {
            t++;
            d_top = frame.offset().top;
          }
          if( (e.pageY + pos_y - drg_h) < frame.offset().top ) {
            t++;
            d_top = frame.offset().top;
          }
          if($drag.offset().top + drg_h > frame.offset().top + frame.outerHeight()){
            t++;
            d_top = frame.offset().top + frame.outerHeight() - drg_h;
          }
          if( (e.pageY + pos_y - drg_h) + drg_h > frame.offset().top + frame.outerHeight()) {
            t++;
            d_top = frame.offset().top + frame.outerHeight() - drg_h;
          }
        } else {
          if($drag.offset().top > frame.offset().top) {
            t++;
            d_top = frame.offset().top;
          }
          if( (e.pageY + pos_y - drg_h) > frame.offset().top ) {
            t++;
            d_top = frame.offset().top;
          }
          if($drag.offset().top + drg_h < frame.offset().top + frame.outerHeight()){
            t++;
            d_top = frame.offset().top + frame.outerHeight() - drg_h;
          }
          if( (e.pageY + pos_y - drg_h) + drg_h < frame.offset().top + frame.outerHeight()) {
            t++;
            d_top = frame.offset().top + frame.outerHeight() - drg_h;
          }
        }

        if(!l) {
          d_left = e.pageX + pos_x - drg_w;
        }
        if(!t) {
          d_top = e.pageY + pos_y - drg_h;
        }

        $('.draggable').offset({
          top: d_top,
          left: d_left
        }).on("mouseup", function() {
          $(this).removeClass('draggable').css('z-index', z_idx);
        });
      });
      e.preventDefault(); // disable selection
    }).on("mouseup", function() {
      if(opt.handle === "") {
        $(this).removeClass('draggable');
      } else {
        $(this).removeClass('active-handle').parent().removeClass('draggable');
      }
      $(this).trigger('updateZoomer');
    });
  }
})(jQuery);