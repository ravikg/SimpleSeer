(function($) {
	$.fn.infiniteScroll = function(options) {
		var defaults = {
			wrapper: "infs-wrapper",
			onScroll: function() {},
			onPage: function() {}
		}

		$.extend(defaults, options);

		return this.each(function(idx, obj) {
			var trigger = _.debounce(defaults.onPage, 300)

			var wrapperConflicts = $(obj).find("."+defaults.wrapper).length
			if(wrapperConflicts === 0) {
				$(obj).wrapInner('<div class="'+defaults.wrapper+'" />');
			}

			$(obj).on('scroll', function(e) {
				var percent = 0;
				var self = $(e.target);
				var selfHeight = self.height();
				var selfScroll = self.scrollTop();
				var wrapperHeight = self.find("." + defaults.wrapper).height();

				if( selfScroll == 0 ) { percent = 0; }
				else { percent = (selfScroll) / (wrapperHeight - selfHeight); percent = Math.ceil(percent * 100); }


				if( wrapperHeight - selfHeight <= selfScroll ) {
					trigger();
				}

				defaults.onScroll(percent);
			});
		});
	}
})(jQuery);
