$.widget("ui.zoomify", {
  options: {realWidth: 0, image: "", zoom: 1, x: 0, y: 0, min: 100, max: 400, height: 0},
  image: {},
  loaded: false,
  viewport: {x: 0, y:0, zoom: 1},

  updateDisplay: function(action) {
  	if(action == undefined){
  	  action = "zoom";
  	}
    var self = this;
    var content = this.element;

    if( !self.loaded ) { return false; }

    var image = content.find(".display").get(0);
    self.image = image;

    var ratio = image.width / image.height;
    content.find(".view").height(image.height + 2);

    var scale = (self.viewport.zoom * 100) / self.options.min;

    var frame = content.find(".frame");
    frame.css({"top": self.viewport.y, "left": self.viewport.x});
    frame.width(image.width / scale);
    frame.height(image.height * self.options.height / scale);

    var frameWidth = Number(frame.css("border-bottom-width").replace(/[a-z]/ig, ""));
    frameWidth = Math.floor(frameWidth);
    frameWidth *= 2;

    if( self.viewport.x < 0 ) {
      var value = 0;
      self.viewport.x = value;
      frame.css("left", value);
    }

    if( self.viewport.y < 0 ) {
      var value = 0;
      self.viewport.y = value;
      frame.css("top", value);
    }

    if( frame.width() + self.viewport.x > image.width - frameWidth ) {
      var value = image.width - Math.ceil(frame.width()) - frameWidth;
      self.viewport.x = value;
      frame.css("left", value);
    }

    if( frame.height() + self.viewport.y > image.height - frameWidth ) {
      var value = image.height - Math.ceil(frame.height()) - frameWidth;
      self.viewport.y = value;
      frame.css("top", value);
    }

    var slider = content.find(".slider");
    slider.css("width", slider.parent().width() - slider.parent().find("input").width() - 30);

    if(action=="zoom"){
      self._trigger("onZoom", null, {
        x: self.viewport.x / image.width,
        y: self.viewport.y / image.height,
        zoom: self.viewport.zoom
      });
    }else{
      self._trigger("onPan", null, {
        x: self.viewport.x / image.width,
        y: self.viewport.y / image.height,
        zoom: self.viewport.zoom
      });
    }
  },

  _create: function() {
    var self = this;
    var options = this.options;

    var element = this.element;
    element.addClass("ui-zoomify");

    self.viewport = {zoom: options.zoom, x: options.x, y: options.y};

    var content = $('<div class="window"><div class="view"><div class="frame"></div><img class="display" style="display: none;" src="'+options.image+'"></div></div><div class="settings"><input type="text" value="" onclick="this.select()"><div class="sliderHolder"><div class="slider"></div></div></div>').appendTo(element);
    content.find("input").attr("value", Math.floor(self.viewport.zoom * 100) + "%");
    content.find(".display").load(function() { self.loaded = true; $(this).fadeIn(300); self.updateDisplay('zoom'); }).bind('dragstart', function(event) { event.preventDefault(); });;

    stuff = {width: element.find(".view").width(), height: options.realHeight * (element.find(".view").width() / options.realWidth)}
    content.find(".view").css("height", stuff.height);

    content.find(".view").click(function(e) {
      self.viewport.x = (e.offsetX || e.originalEvent.layerX - $(e.target).position().left) - content.find(".frame").width() / 2;
      self.viewport.y = (e.offsetY || e.originalEvent.layerY - $(e.target).position().top) - content.find(".frame").height() / 2;
      self.updateDisplay('pan');
    });

    content.find(".frame").draggable({
      containment: "parent",
      drag: function(event, ui) {
         self.viewport.x = ui.position.left;
         self.viewport.y = ui.position.top;
         self.updateDisplay('pan');
      }
    });

    content.find(".slider").slider({
      min: options.min,
      max: options.max,
      value: (options.zoom * 100),
      slide: function(event, ui) {
        value = Math.floor(ui.value);
        $(this).parent().parent().find("input").attr("value",  value + "%");
        self.viewport.zoom = content.find("input").attr("value").replace(/\%/g, "") / 100;
        self.updateDisplay('zoom');
        self.viewport.x = content.find(".frame").position().left;
        self.viewport.y = content.find(".frame").position().top;
        self.updateDisplay('pan');
      }
    });

    content.find("input[type=text]").keypress(function(e) {
      if(e.which == 13){
        var input = $(this);
        var value = Math.floor(Math.min(Math.max(parseInt(input.attr("value"), 10), self.options.min), self.options.max));
        content.find(".slider").slider("option", "value", value);
        input.attr("value", value + "%");
        self.viewport.zoom = value / 100;
        self.updateDisplay('zoom');
      }
    });

    //$(window).resize(function() { self.updateDisplay('zoom'); });
  },

  repaint: function() {
    var self = this;
    self.updateDisplay();
  },

  _setOption: function(option, value) {
    var self = this;

    $.Widget.prototype._setOption.apply( this, arguments );
    switch(option) {
      case "image":
        self.options.image = value;
        this.element.find("#display").attr("src", value);
        break;
      case "zoom":
      	value = Math.max(value, self.options.min / 100)
      	value = Math.min(value, self.options.max / 100)
        self.options.zoom = value;
        self.viewport.zoom = value;
        self.element.find(".slider").slider("option", "value", value * 100);
        self.element.find("input[type=text]").attr("value", Math.floor(value * 100) + "%");
        self.updateDisplay('zoom');
        break;
      case "x":
        self.options.x = value;
        self.viewport.x = value * self.image.width
        self.updateDisplay('pan');
        break;
      case "y":
        self.options.y = value;
        self.viewport.y = value * self.image.height
        self.updateDisplay('pan');
        break;
      case "min":
        self.options.min = Math.floor(value);
        self.options.y = self.viewport.y = self.options.x = self.viewport.x = 0;
        self.element.find(".slider").slider("option", "min", value);
        self.updateDisplay('zoom');
        break;
      case "max":
        self.options.max = Math.floor(value);
        self.options.y = self.viewport.y = self.options.x = self.viewport.x = 0;
        self.element.find(".slider").slider("option", "max", value);
        self.updateDisplay('zoom');
        break;
      case "height":
        self.options.height = value;
        self.updateDisplay('pan');
    }
  }
});
