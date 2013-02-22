(function($) {
	$.fn.infiniteScroll = function(options) {
		var defaults = {
			wrapper: "infs-wrapper",
			callback: function() {}
		}

		$.extend(defaults, options);

		return this.each(function(idx, obj) {
			$(obj).wrapInner('<div class="'+defaults.wrapper+'" />');
			$(obj).on('scroll', function(e) {
				var percent = 0;
				var self = $(e.target);
				var selfHeight = self.height();
				var selfScroll = self.scrollTop();
				var wrapperHeight = self.find("." + defaults.wrapper).height();

				if( selfScroll == 0 ) { percent = 0; }
				else if( wrapperHeight - selfHeight <= selfScroll ) { percent = 100; }
				else { percent = (selfScroll) / (wrapperHeight - selfHeight); percent = Math.ceil(percent * 100); }
				
				defaults.callback(percent)							
			});
		});
	}
})(jQuery);