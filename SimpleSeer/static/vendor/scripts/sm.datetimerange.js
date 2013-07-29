/**
 * A collection of useful and reusable
 * date and time tools.
 */

SimpleSeerDateHelper = {
    dayInitials: ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
    monthNames: ['January','February','March','April','May','June','July','August','September','October','November','December'],
    monthAbbr: ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sept','Oct','Nov','Dec'],
    monthDays: [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31],

    offsetMonth: function(date, span) {
        var theDate = new Date(date.toISOString());
        theDate.setMonth(theDate.getMonth() + span);
        return theDate;
    },

    prettyDate: function(date) {
        var str = [this.monthAbbr[date.getMonth()], " ", date.getDate(), ", ", date.getFullYear()];
	    return str.join("");
    },

    prettyTime: function(d) {
      var hh = d.getHours();
      var m = d.getMinutes();
      var h = hh;
      var s = '00';

      m = m < 10 ? ("0" + m) : m;
      h = h < 10 ? ("0" + h) : h;

      return [h, m, s].join(":");
    },

    flushtime: function(timeString) {
        timeString = timeString.toLowerCase();

        var extension = "";


        timeString = timeString.split(":");
        if( timeString.length == 2 ) { timeString.push("00"); }
        else if( timeString.length == 1 ) { timeString.push("00", "00"); }
        return timeString.join(":") + extension;
    },

    universalizeTime: function(str) {
      return str;
    }
}

/**
 * The DateTimerRange widget definition.
 */

$.widget("ui.datetimerange", {
    options: {
        startDate: (new Date()),
        endDate: (new Date())
    },

    _theMonth: "",
    _inChange: false,
    window: "",
    leftSide: "",
    rightSide: "",
    calendarModels: [],
    calendarViews: [],
    prevStartDate: "",
    prevEndDate: "",

    _setVisibleMonth: function() {
        var self = this;
        var options = this.options;

        if( options.endDate - options.startDate < 2592000000 ) {
            self._theMonth = new Date(options.endDate);
        } else {
            self._theMonth = SimpleSeerDateHelper.offsetMonth(options.startDate, 1);
        }
    },

    _create: function() {
        var self = this;
        self._setVisibleMonth();

        var options = this.options;
        var element = this.element;
        element.bind("focus", function(e, ui) { self.appear(e, ui); });
        element.css("cursor", "pointer");

        this.window = $("<div></div>")
                        .hide()
                        .addClass("ui-datetimerange")
                        .css({
                            "top": element.offset().top + element.height() - $(window).scrollTop(),
                            "left": element.position().left
                        })
                        .appendTo("body");

        this.leftSide = $("<div></div>")
                            .addClass("left")
                            .appendTo(this.window);

        this.rightSide = $(
            '<div>'+
                '<div class="block">'+
                    '<label>From:</label>'+
                    '<input class="ss-date-from" type="text">'+
                    ' - '+
                    '<input class="ss-time-from" type="text" value="'+SimpleSeerDateHelper.prettyTime(options.startDate)+'">'+
                '</div>'+
                '<div class="block">'+
                    '<label>To:</label>'+
                     '<input class="ss-date-to" type="text">'+
                    ' - '+
                    '<input class="ss-time-to" type="text" value="'+SimpleSeerDateHelper.prettyTime(options.endDate)+'">'+
                '</div>'+
                '<div class="bottom">'+
                    '<button class="cancel controlButton">Cancel</button>'+
                    '<button class="apply controlButton">Apply</button>'+
                '</div>'+
            '</div>'
        )
        .addClass("right")
        .appendTo(this.window);

        var goBackMonth = $('<button class="controlButton">&laquo;</button>;').addClass("switch").appendTo(this.leftSide);

        for(var e=0; e<2; e++) {
            self.calendarViews[e] = $("<div></div>")
                                        .addClass("ss-calendar")
                                        .appendTo(this.leftSide);

            self.calendarModels[e] = new Calendar(self.calendarViews[e], {
                startDate: options.startDate,
                endDate: options.endDate,
                month: SimpleSeerDateHelper.offsetMonth(self._theMonth, -1 + e)
            });
        }

        var goNextMonth = $('<button class="controlButton">&raquo;</button>;').addClass("switch").appendTo(this.leftSide);

        /**
         * Event handling and other miscellaneous
         * tweaks to the interface.
         */

        self.window.on("click", ".ss-calendar .date", function() {
            var eleDate = new Date($(this).attr("data-date"));

            if( self._inChange == false ) {
                self._inChange = true;
                self.rightSide.find(".apply").attr("disabled", "disabled");
                self.rightSide.find(".cancel").attr("disabled", "disabled");

                options.startDate = eleDate;
                options.endDate = eleDate;

                $(".ss-date-from").removeClass("alter");
                $(".ss-date-to").addClass("alter");
            } else if( eleDate >= options.startDate ) {
                self._inChange = false;
                self.rightSide.find(".apply").removeAttr("disabled");
                self.rightSide.find(".cancel").removeAttr("disabled");
                options.endDate = eleDate;

                $(".ss-date-from").addClass("alter");
                $(".ss-date-to").removeClass("alter");
            }

            self.updateCalendars();
        });

        /*$(".ss-time-from, .ss-time-to").blur(function() {
           $(this).attr("value", SimpleSeerDateHelper.flushtime($(this).attr("value")));
        });*/

        $('.ss-time-from').timepicker({
            template: false,
            showInputs: false,
            minuteStep: 5,
            showMeridian: false
        });

        $('.ss-time-to').timepicker({
            template: false,
            showInputs: false,
            minuteStep: 5,
            showMeridian: false
        });

        goBackMonth.click(function() {
           self._theMonth = SimpleSeerDateHelper.offsetMonth(self._theMonth, -1);
           for(var e=0; e<self.calendarModels.length; e++) {
                self.calendarModels[e].setMonth(SimpleSeerDateHelper.offsetMonth(self._theMonth, -1 + e));
           }
        });

        goNextMonth.click(function() {
           self._theMonth = SimpleSeerDateHelper.offsetMonth(self._theMonth, 1);
           for(var e=0; e<self.calendarModels.length; e++) {
                self.calendarModels[e].setMonth(SimpleSeerDateHelper.offsetMonth(self._theMonth, -1 + e))
           }
        });

        self.rightSide.find(".cancel").click(function() {

            self.disappear();
            options.startDate = self.prevStartDate;
            options.endDate = self.prevEndDate;
            self.updateCalendars();

        });

        self.rightSide.find(".apply").click(function() {
            if( self._inChange === true ) { return; }

            _sd = self.options.startDate;
            _ed = self.options.endDate;

            _st = SimpleSeerDateHelper.universalizeTime(self.window.find(".ss-time-from").attr("value")).split(":");
            if(_st.length == 2) {
                _st.push("00");
            }
            _et = SimpleSeerDateHelper.universalizeTime(self.window.find(".ss-time-to").attr("value")).split(":");
            if(_et.length == 2) {
                _et.push("00");
            }

            self._trigger("onUpdate", null, {
                startDate: new Date(_sd.getYear() + 1900, _sd.getMonth(), _sd.getDate(), _st[0], _st[1], _st[2]),
                endDate: new Date(_ed.getYear() + 1900, _ed.getMonth(), _ed.getDate(), _et[0], _et[1], _et[2])
            });

            self.disappear();
            self.setPreviousDates();
        });

        this.setPreviousDates();
        this.updateCalendars();
        this._onUpdate();
    },

    destroy: function() {
        this.rightSide.off().unbind().remove()
        this.leftSide.off().unbind().remove()
        this.window.off().unbind().remove()
        this.element.off().unbind('click')
        $.Widget.prototype.destroy.call(this);
    },

    _setOption: function(key, value) {
        var self = this;
        $.Widget.prototype._setOption.apply(this, arguments);
        if(key == "startDate") {
            self.setStartDate(value);
        } else if( key == "endDate") {
            self.setEndDate(value);
        }
    },

    _onUpdate: function() {
        var element = this.element;
        var fromDate = SimpleSeerDateHelper.prettyDate(this.options.startDate);
        var toDate = SimpleSeerDateHelper.prettyDate(this.options.endDate);

        this.window.find(".ss-date-from").attr("value", fromDate);
        this.window.find(".ss-date-to").attr("value", toDate);
    },

    updateCalendars: function() {
        var self = this;

        for(var e=0; e<self.calendarModels.length; e++) {
             self.calendarModels[e].setStartDate(self.options.startDate);
             self.calendarModels[e].setEndDate(self.options.endDate);
             self.calendarModels[e].setMode(self._inChange);
        }

        self._onUpdate();
    },

    /**
     * Getters and Setters
     */

    setStartDate: function(date) {
        var options = this.options;
        options.startDate = date;
        this.updateCalendars();
    },

    setEndDate: function(date) {
        var options = this.options;
        options.endDate = date;
        this.updateCalendars();
    },

    setPreviousDates: function() {
        var options = this.options;
        this.prevStartDate = options.startDate;
        this.prevEndDate = options.endDate;
    },

    /**
     * Widget specific code
     */

    appear: function(e, ui) {
        var self = this;
        var element = this.element;

        self._setVisibleMonth();
        for(var e=0; e<self.calendarModels.length; e++) {
            self.calendarModels[e].setMonth(SimpleSeerDateHelper.offsetMonth(self._theMonth, -1 + e))
        }

        self.window.css({
            "top": element.offset().top + element.height() - $(window).scrollTop(),
            "left": element.offset().left
        }).fadeIn(150);
    },

    disappear: function(e, ui) {
        this.window.fadeOut(150);
    }
});

/**
 * Calendar class will take in a container
 * and some settings to create the markup
 * for the calendar.
 */

function Calendar(element, settings) {
    var settings = settings;

    var table = $('<div class="caltable"></div>')
                    .append($('<div class="caption"></div><div class="head"><div class="row"></div></div><div class="body"></div>'))
                    .appendTo(element);

    for(var i=0; i<SimpleSeerDateHelper.dayInitials.length; i++) {
        table.find(".head .row").append(
            '<div class="cell">'+ SimpleSeerDateHelper.dayInitials[i] + '</div>'
        );
    }

    function markup() {
        var month = settings.month.getMonth();
        var year = settings.month.getFullYear();
        var day = settings.month.getDate();
        var firstDayDate = new Date(year, month, 1);
        var firstDay = firstDayDate.getDay();

        table.find(".caption").html(SimpleSeerDateHelper.monthNames[month] + " " + year);
        table.find(".body").html("");

        var j = 0;
        for(var w=0; w<6; w++) {
            var row = $("<div class='row'></div>").appendTo(table.find(".body"));

            for(var d=0; d<7; d++) {
                var cell = $("<div class='cell'></div>").appendTo(row);
                var jDate = new Date(year, month, (j-firstDay+1));
                var sDate = new Date(settings.startDate.getYear() + 1900, settings.startDate.getMonth(), settings.startDate.getDate())
                var eDate = new Date(settings.endDate.getYear() + 1900, settings.endDate.getMonth(), settings.endDate.getDate())

                if ( (j < firstDay) || (j > (getDaysInMonth(month, year) + firstDay - 1)) ) {

                } else {
                    cell.html(j - firstDay + 1).addClass("date").attr("data-date", jDate.toISOString());

                    if( settings.isEdit && jDate < settings.startDate ) { cell.addClass("static"); }
                    if( jDate >= sDate && jDate <= eDate ) { cell.addClass("selected"); }
                }

                j++;
            }
        }
    }

    function getDaysInMonth(month,year){
        if ((month==1)&&(year%4==0)&&((year%100!=0)||(year%400==0))){
          return 29;
        } else {
          return SimpleSeerDateHelper.monthDays[month];
        }
    }

    function draw() {
        markup();
    }

    this.setStartDate = function(date) {
        settings.startDate = date;
        draw();
    }

    this.setEndDate = function(date) {
        settings.endDate = date;
        draw();
    }

    this.setMonth = function(date) {
        settings.month = date;
        draw();
    }

    this.setMode = function(isEdit) {
        settings.isEdit = isEdit;
        draw();
    }

    draw();

    this.draw = draw;
}
