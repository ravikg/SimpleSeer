var jquery = "http://ajax.googleapis.com/ajax/libs/jquery/1.6.1/jquery.min.js";

var system = require('system');
if (system.args.length !== 2) { phantom.exit(1); }

var page = require('webpage').create();
page.onConsoleMessage = function(msg) { console.log(msg); };
page.open(system.args[1], function(status) {

    if (status !== "success") {

        console.log("Unable to access network");
        phantom.exit(1);

    } else {

        waitFor(theTestsToRun, function(){
            page.includeJs(jquery, function() {
                var exitCode = page.evaluate(function(){
                    var red   = '\033[0;31m';
                    var gray  = '\033[0;32m'
                    var reset = '\033[0m';
                    var count = 0;
                    var total = 0;
                    var start = new Date();

                    var rootSuites = $(".results > .summary > .suite")
                    recurseSuites(rootSuites, 1);

                    function tabLevel(level) { str = ""; for(var i=0; i<level; i++) { str += "    "; }; return str; }
                    function recurseSuites(suites, level) {
                      if(suites && suites.length > 0) {
                        for(var i=0; i<suites.length; i++) {

                          var suite       = suites[i];
                          var suiteTitle  = $("> .description", suite).html();
                          var suiteStatus = $("> .description", suite).hasClass("passed");
                          var suiteTests  = $("> .specSummary", suite);
                          var subSuites   = $("> .suite", suite);

                          console.log(tabLevel(level) + suiteTitle);

                          for(var a=0; a<suiteTests.length; a++) {

                            var test        = suiteTests[a]
                            var testTitle   = $("> .description", test).html();
                            var testStatus  = $(test).hasClass("passed");
                            var symbol      = (testStatus ? "\u2714" : "\033[31m\u2716\033[0m");

                            total++; if( !testStatus ) { count++; }
                            console.log(tabLevel(level + 1) + (testStatus? gray : red) + symbol + reset + " " + testTitle );

                          }

                          if( subSuites.length ) { recurseSuites(subSuites, level + 1); }

                        }
                      }
                    }

                    var end = new Date();
                    console.log("");

                    if( total == 0 ) {
                        console.log("\t\033[31m\u2716 Unexpected error occured. No tests ran.\033[0m")
                        return 1
                    } else {
                        var tx = (count > 0 ? "\033[31m\u2716 " + count + " of " + total + " tests failed\033[0m" : "\033[32m\u2714 All tests passed\033[0m")
                        console.log("\tTest Suite Finished (" + (end-start) + "ms)")
                        console.log("\t" + tx)
                        return count > 0 ? 0 : 1                        
                    }

                });

                phantom.exit(exitCode);
            });
        });
    }
});

function theTestsToRun(){
    return page.evaluate(function(){
        return document.body.querySelector('.symbolSummary .pending') === null
    });
}

/**
 * Wait until the test condition is true or a timeout occurs. Useful for waiting
 * on a server response or for a ui change (fadeIn, etc.) to occur.
 *
 * @param testFx javascript condition that evaluates to a boolean,
 * it can be passed in as a string (e.g.: "1 == 1" or "$('#bar').is(':visible')" or
 * as a callback function.
 * @param onReady what to do when testFx condition is fulfilled,
 * it can be passed in as a string (e.g.: "1 == 1" or "$('#bar').is(':visible')" or
 * as a callback function.
 * @param timeOutMillis the max amount of time to wait. If not specified, 3 sec is used.
 */
function waitFor(testFx, onReady, timeOutMillis) {
    var maxtimeOutMillis = timeOutMillis ? timeOutMillis : 3001, //< Default Max Timeout is 3s
        start = new Date().getTime(),
        condition = false,
        interval = setInterval(function() {
            if ( (new Date().getTime() - start < maxtimeOutMillis) && !condition ) {
                // If not time-out yet and condition not yet fulfilled
                condition = (typeof(testFx) === "string" ? eval(testFx) : testFx()); //< defensive code
            } else {
                if(!condition) {
                    // If condition still not fulfilled (timeout but condition is 'false')
                    console.log("'waitFor()' timeout");
                    phantom.exit(1);
                } else {
                    // Condition fulfilled (timeout and/or condition is 'true')
                    //console.log("'waitFor()' finished in " + (new Date().getTime() - start) + "ms.");
                    typeof(onReady) === "string" ? eval(onReady) : onReady(); //< Do what it's supposed to do once the condition is fulfilled
                    clearInterval(interval); //< Stop this interval
                }
            }
        }, 100); //< repeat check every 100ms
};
