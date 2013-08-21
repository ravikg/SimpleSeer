import time
import gevent
import os, subprocess, glob
from .base import Command
from path import path
from dateutil import parser
import os.path
from datetime import datetime
import fnmatch
import itertools
import warnings
import re
import pkg_resources
import unittest
import sys
from path import path

class CoreCommand(Command):
    'Run the core server / state machine'
    use_gevent = True

    def __init__(self, subparser):
        subparser.add_argument('program', default='', nargs="?")
        subparser.add_argument('--procname', default='corecommand', help='give each process a name for tracking within session')

    def run(self):
        from SimpleSeer.states import Core

        core = Core(self.session)
        found_statemachine = False

        program = self.options.program or self.session.statemachine or 'states.py'

        with open(program) as fp:
            exec fp in dict(core=core)
            found_statemachine = True

        if not found_statemachine:
            raise Exception("State machine " + self.options.program + " not found!")

        try:
            core.run()
        except KeyboardInterrupt as e:
            print "Interupted by user"


@Command.simple(use_gevent=False)
def ControlsCommand(self):
    '''Run a control event server'''
    from SimpleSeer.Controls import Controls

    if self.session.arduino:
       Controls(self.session).run()

class WebCommand(Command):
    '''Run the web server'''

    def __init__(self, subparser):
        subparser.add_argument('--procname', default='web', help='give each process a name for tracking within session')
        subparser.add_argument('--test', default=None, help='Run testing suite (use: --test=1)')


    def run(self):
        'Run the web server'
        from SimpleSeer.Web import WebServer, make_app
        from SimpleSeer import models as M
        from pymongo import Connection, DESCENDING, ASCENDING
        from SimpleSeer.models.Inspection import Inspection, Measurement
        import mongoengine

        # Plugins must be registered for queries
        Inspection.register_plugins('seer.plugins.inspection')
        Measurement.register_plugins('seer.plugins.measurement')

        db = mongoengine.connection.get_db()
        # Ensure indexes created for filterable fields
        # TODO: should make this based on actual plugin params or filter data
        try:
            db.frame.ensure_index([('results', 1)])
            db.frame.ensure_index([('results.measurement_name', 1)])
            db.frame.ensure_index([('results.numeric', 1)])
            db.frame.ensure_index([('results.string', 1)])
        except:
            self.log.info('Could not create indexes')
        web = WebServer(make_app(test = self.options.test))

        from SimpleSeer.Backup import Backup
        Backup.importAll(None, False, True, True)

        try:
            web.run_gevent_server()
        except KeyboardInterrupt as e:
            print "Interrupted by user"

@Command.simple(use_gevent=True)
def OPCCommand(self):
    '''Run the opc server
    You will also need to add the following to your config file:
    opc:
      server: 10.0.1.107
      name: OPC SERVER NAME
      tags: ["OPC-SERVER.Brightness_1.Brightness", "OPC-SERVER.TAGNAME"]
      tagcounter: OPC-SERVER.tag_which_is_int_that_tells_frame_has_changed


    This also requires the server you are connecting to be running the OpenOPC
    gateway service.  It comes bundled with OpenOPC.  To get it to route over
    the network you also have to set the windows environment variable OPC_GATE_HOST
    to the actual of the IP address of the server it's running on instead of 'localhost'
    otherwise the interface doesn't bind and you won't be able to connect via
    linux.
    '''
    try:
        import OpenOPC
    except:
        raise Exception('Requires OpenOPC plugin')

    from SimpleSeer.realtime import ChannelManager
    opc_settings = self.session.opc

    if opc_settings.has_key('name') and opc_settings.has_key('server'):
      self.log.info('Trying to connect to OPC Server[%s]...' % opc_settings['server'])
      try:
        opc_client = OpenOPC.open_client(opc_settings['server'])
      except:
        ex = 'Cannot connect to server %s, please verify it is up and running' % opc_settings['server']
        raise Exception(ex)
      self.log.info('...Connected to server %s' % opc_settings['server'])
      self.log.info('Mapping OPC connection to server name: %s' % opc_settings['name'])
      opc_client.connect(opc_settings['name'])
      self.log.info('Server [%s] mapped' % opc_settings['name'])

    if opc_settings.has_key('tagcounter'):
      tagcounter = int(opc_client.read(opc_settings['tagcounter'])[0])

    counter = tagcounter
    self.log.info('Polling OPC Server for triggers')
    while True:
      tagcounter = int(opc_client.read(opc_settings['tagcounter'])[0])

      if tagcounter != counter:
        self.log.info('Trigger Received')
        data = dict()
        for tag in opc_settings.get('tags'):
          tagdata = opc_client.read(tag)
          if tagdata:
            self.log.info('Read tag[%s] with value: %s' % (tag, tagdata[0]))
            data[tag] = tagdata[0]

        self.log.info('Publishing data to PUB/SUB OPC channel')
        ChannelManager().publish('opc/', data)
        counter = tagcounter

class MaintenanceCommand(Command):

    def __init__(self, subparser):
        subparser.add_argument('--message', default=None, help='Message to show the user')
        pass

    def run(self):
        'Run the maintenance web server'
        from flask import request, make_response, Response, redirect, render_template, Flask
        import flask
        from SimpleSeer.Session import Session
        from datetime import datetime

        start_time = str(datetime.now().strftime("%B %d, %Y at %H:%M (EST)"))

        print "Maintenance mode started at {0}".format(start_time)

        yaml_config = Session.read_config()

        pstring = yaml_config['web']['address'].split(":")
        if len(pstring) is 2:
            port = int(pstring[1])
        else:
            port = 5000
        tpath = path("{0}/{1}".format(yaml_config['web']['static']['/'], '../templates')).abspath()
        template_folder = tpath
        app = Flask(__name__,template_folder=template_folder)

        if self.options.message:
            message = self.options.message
        else:
            message = ''

        @app.route("/")
        def maintenance():
            return render_template("maintenance.html", params = dict(start_time=start_time, message=message))

        @app.errorhandler(404)
        def page_not_found(e):
            return render_template('maintenance.html', params = dict(start_time=start_time, message=message))

        @app.errorhandler(500)
        def internal_server_error(e):
            return render_template('maintenance.html', params = dict(start_time=start_time, message=message))

        try:
            app.run(port=port)
        except KeyboardInterrupt as e:
            print "Interrupted by user"


class ModBusCommand(Command):
    use_gevent = False

    '''Modbus'''
    def run(self):
        from SimpleSeer.modbus import ModBusService
        ModBusService().start(verbose=True)

class ScrubCommand(Command):
    use_gevent = False
    def __init__(self, subparser):
        subparser.add_argument("-t", "--thumbnails", dest="thumbnails", default=False, action="store_true")
        subparser.add_argument("-o", "--orphans", dest="orphans", default=False, action="store_true")


    def run(self):
        from SimpleSeer.realtime import ChannelManager

        'Run the frame scrubber'
        from SimpleSeer import models as M

        if self.options.thumbnails:
            self.log.info("Scrubbing cached thumbnails from Frame collection")
            for f in M.Frame.objects(thumbnail_file__ne = None):
                f.thumbnail_file.delete()
                f.thumbnail_file = None
                f.save(publish = False)
            return

        if self.options.orphans:
            self.log.info("Scrubbing orphaned gridfs file objects")
            db = M.Frame._get_db()
            import gridfs
            fs = gridfs.GridFS(db)
            fileids = db.fs.files.find(fields = ['_id'])
            thumbnails = db.frame.find(fields = ['thumbnail_file'])
            images = db.frame.find(fields = ['imgfile'])

            parented = {}
            for t in thumbnails:
                parented[t['thumbnail_file']] = 1

            for i in images:
                parented[i['imgfile']] = 1

            deletedfiles = 0
            for f in fileids:
                if not parented.get(f['_id'], False):
                    #delete the orphan
                    fs.delete(f['_id'])
                    deletedfiles += 1

            self.log.info("Deleted {} orphaned files".format(deletedfiles))
            return


        retention = self.session.retention
        if not retention:
            self.log.info('No retention policy set, skipping cleanup')
            return

        first_capturetime = ''
        while retention['interval']:
            if not M.Frame._get_db().metaschedule.count():
                q_csr = M.Frame.objects(imgfile__ne = None)
                q_csr = q_csr.order_by('-capturetime')
                q_csr = q_csr.skip(retention['maxframes'])
                numframes = q_csr.count()
                self.log.info("Preparing to scrub {} files".format(numframes))
                index = 0
                for f in q_csr:
                    if not first_capturetime:
                        first_capturetime = f.capturetime_epoch
                    # clean out the fs.files and .chunks
                    f.imgfile.delete()
                    f.imgfile = None

                    index += 1
                    if retention.get('purge',False):
                        f.delete(publish = False)
                        if not index % 100:
                            self.log.info("deleted {} frames".format(index))
                    else:
                        if not index % 100:
                            self.log.info("deleted image from {} frames".format(index))
                        f.save(False)

                # Rebuild the cache
                if retention.get('purge', False):
                    res = ChannelManager().rpcSendRequest('olap_req/', {'action': 'scrub', 'capturetime_epoch__lte': first_capturetime})

                # This line of code needed to solve fragmentation bug in mongo
                # Can run very slow when run on large collections
                db = M.Frame._get_db()
                if 'fs.files' in db.collection_names():
                    db.command({'compact': 'fs.files'})
                if 'fs.chunks' in db.collection_names():
                    db.command({'compact': 'fs.chunks'})

                self.log.info('Scrubbed %d frame files', numframes)
            else:
                self.log.info('Backfill in progress.  Waiting to scrub')
            time.sleep(retention["interval"])

@Command.simple(use_gevent=False)
def ShellCommand(self):
    '''Run the ipython shell'''
    import subprocess
    import os

    if os.getenv('DISPLAY'):
      cmd = ['ipython','--ext','SimpleSeer.ipython','--pylab']
    else:
      cmd = ['ipython','--ext','SimpleSeer.ipython']

    subprocess.call(cmd, stderr=subprocess.STDOUT)


class NotebookCommand(Command):
    '''Run the ipython notebook server'''

    def __init__(self, subparser):
        subparser.add_argument("--port", help="port defaults to 5050", default="5050")
        subparser.add_argument("--ip", help="the IP, defaults to 127.0.0.1", default="127.0.0.1")
        subparser.add_argument("--notebook-dir", help="the notebook directory, defaults to ./notebooks", default="notebooks")


    def run(self):
        from ..notebook import contextDict
        import subprocess
        import os, os.path
        if not os.path.exists(self.options.notebook_dir):
            os.makedirs(self.options.notebook_dir)

        # Since these errors will get swallowed by the ipython proc call, pre-test them:
        try:
            contextDict()
        except Exception as e:
            self.log.info('Error setting up notebook context: {}.  Continuting to load, but some globals will not be available.'.format(e))

        subprocess.call(["ipython", "notebook",
                '--port', self.options.port,
                '--ip', self.options.ip,
                '--notebook-dir', self.options.notebook_dir,
                '--ext', 'SimpleSeer.notebook', '--pylab', 'inline'], stderr=subprocess.STDOUT)



class MetaCommand(Command):
    '''Import and export project database'''
    def __init__(self, subparser):
        subparser.add_argument('subsubcommand', help="metadata [import|export]", default="export")
        subparser.add_argument("--listen", help="(export) Run as daemon listing for changes and exporting when changes found.", action='store_true')
        subparser.add_argument("--file", help="The file name to export/import.  If blank, defaults to seer_export.yaml", default="seer_export.yaml")
        subparser.add_argument('--clean', help="(import) Delete existing metadata before importing", action='store_true')
        subparser.add_argument('--skipbackfill', help="(import) Do not run a backfill after importing", action='store_true')

        subparser.add_argument('--procname', default='meta', help='give each process a name for tracking within session')


    def run(self):
        from SimpleSeer.Backup import Backup

        if self.options.subsubcommand != 'import' and self.options.subsubcommand != 'export':
            self.log.info("Valid subcommands are import and export.  Ignoring \"{}\".".format(self.options.subsubcommand))
        if self.options.subsubcommand == "export" and self.options.clean:
            self.log.info("Clean option not applicable when exporting.  Ignoring")
        if self.options.subsubcommand == "import" and self.options.listen:
            self.log.info("Listen option not applicable when importing.  Ignorning")

        if self.options.subsubcommand == "export":
            Backup.exportAll()
            if self.options.listen:
                gevent.spawn_link_exception(Backup.listen())
        elif self.options.subsubcommand == "import":
            Backup.importAll(self.options.file, self.options.clean, self.options.skipbackfill)


class ExportImagesCommand(Command):

    def __init__(self, subparser):
        subparser.add_argument("--number", help="This is the number of lastframes you want, use 'all' if you want all the images ever", default='all', nargs='?')
        subparser.add_argument("--dir", default=".", nargs="?")
        from argparse import RawTextHelpFormatter, RawDescriptionHelpFormatter
        subparser.formatter_class=RawDescriptionHelpFormatter
        help_text = '''
        This will export images with the mongo query specified 'i.e. Frame.objects(query_here)'
        To use, you would normally run the query as:
        Frame.objects(id='502bfa6856a8bf1e755c702d', width__gte = 50)

        You need to structure the query as a dictionary like:
        "{'id':'502bfa6856a8bf1e755c702d', 'width__gte': '50'}"

        So you would run the command as:
        simpleseer export-images-query "{'id':'502bfa6856a8bf1e755c702d', 'width__gte': '50'}"
        '''
        subparser.add_argument("--query", help=help_text, nargs="?")

    def run(self):
        "Dump the images stored in the database to a local directory in standard image format"
        from SimpleSeer import models as M
        from SimpleSeer.Session import Session
        from SimpleSeer.util import jsonencode
        import ast
        import urllib2


        query = {}
        if self.options.query:
            query = self.options.query
            query = ast.literal_eval(query)

        number_of_images = self.options.number

        if number_of_images != 'all':
            number_of_images = int(number_of_images)
            frames = M.Frame.objects(**query).order_by("-capturetime").limit(number_of_images)
        else:
            frames = M.Frame.objects(**query).order_by("-capturetime")

        out_dir = path(self.options.dir)
        framecount = len(frames)
        digits = len(str(framecount))
        database = Session().database


        for counter, frame in enumerate(frames):
            trunctime = str(frame.capturetime)
            if re.match("^(.*\.\d\d)", trunctime):
                trunctime = re.match("^(.*\.\d\d)", trunctime).group(1)
            name = "__".join([database,
                str(counter).zfill(digits),  #frame #
                trunctime,  #time of capture
                #"__".join(["{}={}".format(k,v) for k,v in frame.metadata.items()]),  #metadata
                #TODO, print this out if v isn't an iter
                frame.camera]) + ".jpg" #camera
            file_name = str(out_dir / name)
            print 'Saving file (',counter,'of',framecount,'):',file_name
            frame.image.save(str(file_name))


class ImportImagesCommand(Command):



    def __init__(self, subparser):
        subparser.add_argument("dir", nargs=1, help="Directory to import/watch from")
        subparser.add_argument("-s", "--schema", dest="schema", default="{database}__{count}__{time}__{camera}", nargs="?", help="Schema for filenames.  Special terms are {time} {camera}, otherwise data will get pushed into metadata.  Python named regex blocks (?P<NAME>.?) may also be used")
        subparser.add_argument("-p", "--withpath", dest="withpath", default=False, action="store_true", help="Match schema on the full path (default to filename)")
        subparser.add_argument("-r", "--recursive", dest="recursive", default=False, action="store_true")
        subparser.add_argument("-f", "--files", dest="files", nargs="?", default="*[bmp|jpg|png]", help="Glob descriptor to describe files to accept")
        subparser.add_argument("-n", "--new", dest="new", default=False, action="store_true", help="Only import files written since the most recent Frame")
        subparser.add_argument("-m", "--metadata", dest="metadata", default="", nargs="?", help="Additional metadata for frame (as a python dict)")
        subparser.add_argument("-t", "--timestring", dest="timestring", default="", nargs="?", help="Python strptime() expression to decode timestamp with")
        subparser.add_argument("-o", "--overwrite", dest="overwrite", default=False, action="store_true", help="Overwrite existing files")

    def import_frame(self, filename, metadata = {}, template = ""):
        import SimpleSeer.models as M
        from SimpleCV import Image
        import copy


        metadata = copy.deepcopy(metadata) #make a copy of metadata so we can add/munge

        frame = M.Frame()
        frame.metadata['filename'] = filename
        frame.metadata['mtime'] = os.path.getmtime(filename)
        if template:
            to_match = filename
            if not self.options.withpath:
                to_match = os.path.basename(filename)
            match = re.match(template, to_match)
            if match:
                metadata.update(match.groupdict())
            else:
                self.log.warn('Failed to match import attribute template on {0}'.format(filename))

        if metadata.get("time", False):
            timestring = metadata.pop('time')
            try:
                if self.options.timestring:
                    frame.capturetime = datetime.fromtimestamp(time.strptime(timestring, self.options.timestring))
                elif self.options.timeregex:
                    _ts = re.sub(self.options.timeregex['match'],self.options.timeregex['replace'],timestring)
                    frame.capturetime = parser.parse(_ts)
                else:
                    frame.capturetime = parser.parse(timestring)
            except Exception as e:
                warnings.warn(str(e))
                frame.metadata['time'] = timestring

        if not frame.capturetime:
            frame.capturetime = datetime.fromtimestamp(os.stat(filename).st_mtime)

        if metadata.get("camera", False):
            frame.camera = metadata.pop('camera')
        else:
            frame.camera = "File"

        frame.localtz = self.session.cameras[0].get('timezone', 'UTC')

        frame.metadata.update(metadata)
        frame.image = Image(filename)

        for inspection in M.Inspection.objects:
            if not inspection.parent:
                if not inspection.camera or inspection.camera == frame.camera:
                    features = inspection.execute(frame)
                    frame.features += features
                    for m in inspection.measurements:
                        m.execute(frame, features)

        frame.save()
        self.log.info("Imported {} at time {} for camera '{}' with attributes {}".format(filename, frame.capturetime, frame.camera, metadata))

    def run(self):
        import SimpleSeer.models as M
        M.Inspection.register_plugins('seer.plugins.inspection')
        M.Measurement.register_plugins('seer.plugins.measurement')

        if self.session.import_params:
            for k,v in self.session.import_params.items():
                self.options.__dict__.update(self.session.import_params)
        M.Frame._get_db().frame.ensure_index("metadata.filename")

        lastimport = 0  #time of last import in epoch, default to epoch

        metadata = {}
        if self.options.metadata:
            metadata = eval(self.options.metadata)

        metadata_params = { "metadata__{}".format(k): v for k, v in metadata.items() if k != 'camera' }
        if metadata.get('camera', False):
            metadata_params['camera'] = metadata['camera']


        if self.options.new:
            lastframes = M.Frame.objects(metadata__filename__exists = True, metadata__mtime__exists = True, **metadata_params).order_by("-metadata__mtime")
            if len(lastframes):
                lastimport = float(lastframes[0].metadata['mtime'])

        def _expandTemplate(match):
            m = match.group(0)
            if m == '{time}':
                return "(?P<time>.*?)"
            if m == '{camera}':
                return "(?P<camera>.*?)"
            else:
                return "(?P<" + m[1:-1] + ">.*?)"

        template = ''
        if self.options.schema:
            template = re.sub("\{\w+\}", _expandTemplate, self.options.schema)
            template += "\.\w+$" #ignore extension

        if self.options.recursive:
            #this got a bit thick
            #walk the tree, match on our "files" glob, if the mtime > lastimport
            files = itertools.chain(
                *[[os.path.join(a, fname) for fname in fnmatch.filter(c, self.options.files) if os.path.getmtime(os.path.join(a, fname)) > lastimport]
                    for a, b, c in os.walk(self.options.dir[0])])
        else:
            files = [ f for f in glob.glob(os.path.join(self.options.dir[0], self.options.files)) if os.path.getmtime(f) > lastimport ]

        for f in files:
            if len(M.Frame.objects(metadata__filename = f, **metadata_params)):
                if self.options.overwrite:
                     M.Frame.objects(metadata__filename = f, **metadata_params).delete()
                else:
                    self.log.info("{} already imported".format(f))
                    continue

            self.import_frame(f, metadata, template)

class UserCommand(Command):
    '''Create a new user'''

    def __init__(self, subparser):
        subparser.add_argument("action", help="The desired user action")
        subparser.add_argument("username", help="Username for new user")
        subparser.add_argument("-n", "--name", dest="name", default=False, help="Full name of new user")
        subparser.add_argument("-p", "--password", dest="password", default=False, help="Password of new user")
        subparser.add_argument("-f", "--force", dest="force", default=False, action="store_true")

    def run(self):
        from SimpleSeer import models as M

        if self.options.action == "add":
            if self.options.username:
                username = self.options.username
                fullname = self.options.name or raw_input("Name: ")
                password = self.options.password or raw_input("Password: ")
                try:
                    user = M.User.objects.create(username=username, password=password)
                    user.name = fullname
                    user.save()
                except:
                    print "Unexpected error:", sys.exc_info()[0]
                    print("Error: User could not be created.")
                    return

        elif self.options.action == "remove":
            if self.options.username:
                try:
                    username = self.options.username
                    user = M.User.objects.get(username=username)
                    if not self.options.force:
                        check = raw_input("Really delete user? (y/n): ")
                        if check is not "y":
                            print("delete cancelled")
                            return
                    user.delete()
                except:
                    print("Error: User not found, aborting.")
                    return


class TestCommand(Command):
    ''' Run the front-end and back-end tests for SimpleSeer. '''

    def __init__(self, subparser):
        # TODO: Add support for optional tld to search 
        # for tests. (unit|functional|integration)   

        # TODO: Add optional verbosity argument. Try to 
        # capture the stderr and stdout of the subprocess
        # calls. (Doesnt seem to be possible to swallow most
        # of what we would want to hide, though..)

        pass

    def run(self):
        logs = []
        missed = 0     
        failed = 0   
        tests = path(pkg_resources.resource_filename('SimpleSeer', 'tests'))
        
        def cleanTestPath(path, nameOnly=False):
            spl = path.split("/")
            if nameOnly:
                bld = spl[-2] + "." + spl[-1].split(".")[0]
            else:
                bld = spl[-2] + "/" + spl[-1]
            return bld

        backTests = glob.glob(tests / "*/test_*.py")
        for test in backTests:
            try:
                pkg = "SimpleSeer.tests.{}".format(cleanTestPath(test, True))
                mod = __import__(pkg, globals(), locals(), ["Test"], -1) 
                suite = unittest.TestLoader().loadTestsFromTestCase(mod.Test)
                result = unittest.TextTestRunner(verbosity=0).run(suite)

                _count = len(result.errors + result.failures)
                if _count is 0:
                    logs.append(u"\t\033[92m\u2714\033[0m {}".format(cleanTestPath(test)))
                else:
                    logs.append(u"\t\033[91m\u2716\033[0m {}".format(cleanTestPath(test)))
                    failed = failed + 1
            except Exception, e:
                logs.append(u"\t\033[91m\u2716\033[0m {}".format(cleanTestPath(test)))
                print("\t\033[93mUnexpected error in {}:".format(cleanTestPath(test)))
                print("\t")
                print(sys.exc_info()[0], e, "\033[0m")
                missed = missed + 1
        
        print("\n"+("-"*70)+"\n")
        print "SimpleSeer Test Results:"
        if missed > 0:
            print "\t[ Could not complete {} test(s). ]".format(missed)
        print "\nBack-end:"
        print "\n".join(logs)

        # Check to see if we are in a client
        # repo. If so, we can run the front
        # end tests.
        if os.path.exists("simpleseer.cfg"):
            from SimpleSeer.tests.tools.seer import SeerInstanceTools

            client = os.getcwd().split("/")[-1]
            bootstrap = tests / "run-jasmine.js"
            webhost = "http://127.0.0.1:9178/"
            config = "{'web': {'address': '127.0.0.1:9178', 'static': {'/': '%s/static'}}}" % client
            seers = SeerInstanceTools()

            print "\nFront-end:"

            seers.spinup_seer('web', config_override=config, pipe=open("/dev/null"))
            frontTests = subprocess.call(["phantomjs", bootstrap, webhost + "/testing"])
            seers.kill_seer('web')
        else:
            print "\nFront-end: Could not execute tests. Re-run tests from inside a client repo."

        if failed + frontTests is 0:
            sys.exit(0)
        else:
            sys.exit(1)
