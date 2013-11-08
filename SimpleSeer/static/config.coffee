exports.config =
  # See docs at http://brunch.readthedocs.org/en/latest/config.html.

  # Edit the next line to change default build path.
  paths:
    public: 'public'

  files:
    javascripts:
      # Defines what file will be generated with `brunch generate`.
      defaultExtension: 'coffee'
      # Describes how files will be compiled & joined together.
      # Available formats:
      # * 'outputFilePath'
      # * map of ('outputFilePath': /regExp that matches input path/)
      # * map of ('outputFilePath': function that takes input path)
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

      # Defines compilation order.
      # `vendor` files will be compiled before other ones
      # even if they are not present here.
      order:
        before: [
          # Everything else
          'vendor/scripts/console-helper.js',
          'vendor/scripts/socket.io.js',
          'vendor/scripts/jquery.js',
          'vendor/scripts/underscore.js',
          'vendor/scripts/backbone.js',
          'vendor/scripts/moment.js',
          'vendor/scripts/md5.js',

          # Unit Testing
          'vendor/scripts/jasmine.js',
          'vendor/scripts/jasmine-html.js',
        ]

    stylesheets:
      defaultExtension: 'less'
      joinTo:
        'stylesheets/seer.css': (path) -> true
      order:
        before: [
          'app/styles/fonts.less',
          'vendor/styles/gridsystem.css',
          'vendor/styles/bootstrap.css'
        ]
        after: [
          #'vendor/styles/bootstrap-responsive.css',
          'vendor/styles/jquery.jqplot.min.css',
          'vendor/styles/themes/base/jquery.ui.core.css',
          'vendor/styles/tablesorter-blue.css',
          'vendor/styles/jquery.tablesorter.pager.css',
          'vendor/styles/jquery.ui.combobox.css',
          'vendor/styles/jquery.ui.zoomify.css',
          'vendor/styles/jquery.tinyscrollbar.css',
          'vendor/styles/sm.datetimerange.css']

    templates:
      defaultExtension: 'hbs'
      joinTo: 'javascripts/seer.js'

  # Change this if you're using something other than backbone (e.g. 'ember').
  # Content of files, generated with `brunch generate` depends on the setting.
  framework: 'backbone'

  # Settings of web server that will run with `brunch watch [--server]`.
  # server:
  #   # Path to your server node.js module.
  #   # If it's commented-out, brunch will use built-in express.js server.
  #   path: 'server.coffee'
  #   port: 3333
  #   # Run even without `--server` option?
  #   run: yes
