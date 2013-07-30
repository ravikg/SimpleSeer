exports.config =
  framework: 'backbone'

  paths:
    public: 'public'

  files:
    javascripts:
      defaultExtension: 'coffee'
      joinTo:
        'javascripts/seer.js': (path) ->
           a = (/^vendor\/tests/).test path
           b = path.indexOf("/jasmine.js") == -1
           c = path.indexOf("/jasmine-html.js") == -1
           return !a && b && c
        'javascripts/seertest.js': (path) ->
           a = (/^vendor\/tests/).test path
           b = path.indexOf("/jasmine.js") > -1
           c = path.indexOf("/jasmine-html.js") > -1
           return a || b || c

      order:
        before: [
          'vendor/scripts/jquery-2.0.0.js'
          'vendor/scripts/handlebars-1.0.0.js'
          'vendor/scripts/underscore-1.5.1.js'
          'vendor/scripts/backbone-1.0.0.js'
        ]

    stylesheets:
      defaultExtension: 'less'
      joinTo:
        'stylesheets/seer.css': (path) -> true

      order:
        before: [
        ]
        after: [
        ]

    templates:
      defaultExtension: 'hbs'
      joinTo: 'javascripts/seer.js'



