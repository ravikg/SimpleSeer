var system = require('system');

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


if (system.args.length !== 2) {
    console.log('Usage: run-jasmine.js URL');
    phantom.exit(1);
}

var page = require('webpage').create();

// Route "console.log()" calls from within the Page context to the main Phantom context (i.e. current "this")
page.onConsoleMessage = function(msg) {
    console.log(msg);
};

page.open(system.args[1], function(status) {
    if (status !== "success") {
        console.log("Unable to access network");
        phantom.exit();
    } else {
        waitFor(function(){
            return page.evaluate(function(){
                return document.body.querySelector('.symbolSummary .pending') === null
            });
        }, function(){
            var exitCode = page.evaluate(function(){

                red   = '\033[0;31m';
                gray  = '\033[0;32m'
                reset = '\033[0m';

                console.log("")

                var count = 0;
                var total = 0;
                var start = new Date();

                var testSuites = document.body.querySelectorAll(".results > .summary > .suite");
                recurseSuites(testSuites);

                function recurseSuites(suites) {
                  if(testSuites && testSuites.length > 0) {

                    for(var i=0; i<testSuites.length; i++) {
                      var title = testSuites[i].querySelector(".description").innerText;
                      var status = testSuites[i].className.replace("suite ", "")
                      console.log("\t" + title);

                      var tests = testSuites[i].querySelectorAll(".specSummary");
                      for( var a=0; a<tests.length; a++) {
                        var testTitle = tests[a].querySelector(".description").innerText;
                        var testStatus = tests[a].className.replace("specSummary ", "");
                        var ch = (testStatus == "passed" ? "\u2714" : "\033[31m\u2716\033[0m");
                        if(testStatus == "failed") count++;
                        total++;
                        console.log("\t    " + ch + (testStatus == "failed" ? red : gray) + " " + testTitle + reset);
                      }

                      console.log("");
                    }

                  }
                }

                var end = new Date();
                console.log("");

                var tx = (count > 0 ? "\033[31m\u2716 " + count + " of " + total + " tests failed\033[0m" : "\033[32m\u2714 All tests passed\033[0m")
                console.log("\tTest Suite Finished (" + (end-start) + "ms)")
                console.log("\t" + tx)

                console.log ("")

            });

            phantom.exit(exitCode);
        });
    }
});
