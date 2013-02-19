(function($) {
	$.fn.infiniteScroll = function(options) {
		var defaults = {
			wrapper: "asb-wrapper",
			callback: function() {}
		}

		$.extend(defaults, options);

		return this.each(function(idx, obj) {
			$(obj).wrapInner('<div class="'+defaults.wrapper+'" />');
			$(obj).on('scroll', function(e) {
				self = $(e.target);
				selfHeight = self.height();
				selfScroll = self.scrollTop();
				wrapperHeight = self.find("." + defaults.wrapper).height();

				atBottom = wrapperHeight - selfHeight <= selfScroll;
				if( atBottom ) {
					defaults.callback()							
				}
			})
		});
	}
})(jQuery);