import time
import gevent
import os, subprocess
from .base import Command
from path import path
from dateutil import parser
import os.path
from datetime import datetime
import fnmatch
import itertools
import warnings
        


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
            core.start_socket_communication()
            core.run()
        except KeyboardInterrupt as e:
            print "Interupted by user"


@Command.simple(use_gevent=False)
def ControlsCommand(self):
    'Run a control event server'
    from SimpleSeer.Controls import Controls
    
    if self.session.arduino:
       Controls(self.session).run()

@Command.simple(use_gevent=True)
def OlapCommand(self):
    try:
        from SeerCloud.OLAPUtils import ScheduledOLAP, RealtimeOLAP, OLAPData
    except:
        print 'Error starting OLAP schedules.  This requires Seer Cloud'
        return 0
    
    from SimpleSeer.models.Inspection import Inspection, Measurement

    try:
        Inspection.register_plugins('seer.plugins.inspection')
        Measurement.register_plugins('seer.plugins.measurement')

        so = ScheduledOLAP()
        gevent.spawn_link_exception(so.runSked)
        
        od = OLAPData()
        gevent.spawn_link_exception(od.listen)
        
        ro = RealtimeOLAP()
        ro.monitorRealtime()
        
    except KeyboardInterrupt as e:
        print "Interrupted by user"

class WebCommand(Command):
    
    def __init__(self, subparser):
        subparser.add_argument('--procname', default='web', help='give each process a name for tracking within session')

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
            
        web = WebServer(make_app())
        try:
            web.run_gevent_server()
        except KeyboardInterrupt as e:
            print "Interrupted by user"
        
@Command.simple(use_gevent=True)
def OPCCommand(self):
    '''
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


@Command.simple(use_gevent=True)
def BrokerCommand(self):
    'Run the message broker'
    from SimpleSeer.broker import PubSubBroker
    from SimpleSeer import models as M
    try:
        psb = PubSubBroker(self.session.pub_uri, self.session.sub_uri)
        psb.start()
        psb.join()
    except KeyboardInterrupt as e:
        print "Interrupted by user"


@Command.simple(use_gevent=False)
def ScrubCommand(self):
    'Run the frame scrubber'
    from SimpleSeer import models as M
    retention = self.session.retention
    if not retention:
        self.log.info('No retention policy set, skipping cleanup')
        return
    while retention['interval']:
        if not M.Frame._get_db().metaschedule.count():
            q_csr = M.Frame.objects(imgfile__ne = None)
            q_csr = q_csr.order_by('-capturetime')
            q_csr = q_csr.skip(retention['maxframes'])
            for f in q_csr:
                # clean out the fs.files and .chunks
                f.imgfile.delete()
                f.imgfile = None
        
                if retention['purge']:
                    f.delete()
                else:
                    f.save(False)
            # This line of code needed to solve fragmentation bug in mongo
            # Can run very slow when run on large collections
            db = M.Frame._get_db()
            if 'fs.files' in db.collection_names():
                db.command({'compact': 'fs.files'})
            if 'fs.chunks' in db.collection_names():
                db.command({'compact': 'fs.chunks'})
        
            self.log.info('Purged %d frame files', q_csr.count())
        else:
            self.log.info('Backfill running.  Waiting to scrub')
        time.sleep(retention["interval"])

@Command.simple(use_gevent=False)
def ShellCommand(self):
    'Run the ipython shell'
    import subprocess
    import os

    if os.getenv('DISPLAY'):
      cmd = ['ipython','--ext','SimpleSeer.ipython','--pylab']
    else:
      cmd = ['ipython','--ext','SimpleSeer.ipython']
      
    subprocess.call(cmd, stderr=subprocess.STDOUT)

@Command.simple(use_gevent=True)
def NotebookCommand(self):
    'Run the ipython notebook server'
    import subprocess
    subprocess.call(["ipython", "notebook",
            '--port', '5050',
            '--ext', 'SimpleSeer.notebook', '--pylab', 'inline'], stderr=subprocess.STDOUT)


        
class MetaCommand(Command):
    
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
        import ast
        
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
            name = "__".join([database,
                str(counter).zfill(digits),  #frame #
                str(frame.capturetime)[:-5],  #time of capture 
                #"__".join(["{}={}".format(k,v) for k,v in frame.metadata.items()]),  #metadata
                #TODO, print this out if v isn't an iter
                frame.camera]) + ".jpg" #camera
            file_name = str(out_dir / name)
            print 'Saving file (',counter,'of',framecount,'):',file_name
            frame.image.save(str(file_name))


class ImportImagesCommand(Command):
    
    def __init__(self, subparser):
        #subparser.add_argument("-w", "--watch", dest="watch", help="continue watching the directory", action="store_true", default=False)
        subparser.add_argument("-s", "--schema", dest="schema", default="{database}__", nargs="?", help="Schema for filenames.  Special terms are {time} {camera}, otherwise data will get pushed into metadata.  Python named regex blocks (?P<NAME>.?) may also be used")
        subparser.add_argument("-p", "--withpath", dest="withpath", default=False, nargs="?", action="store_true", help="Match schema on the full path (default to filename)")
        subparser.add_argument("-d", "--dir", dest="dir", nargs="?", default=".", help="Directory to import/watch from")
        subparser.add_argument("-r", "--recursive", dest="recursive", default=False, action="store_true")
        subparser.add_argument("-f", "--files", dest="files", nargs="?", default="*.\[bmp|jpg|png\]", help="Glob descriptor to describe files to accept")
        subparser.add_argument("-a", "--all", dest="new", nargs="?", default=False, action="store_true", help="Only import files written since the most recent Frame")
        subparser.add_argument("-m", "--metadata", dest="metadata", default="", nargs="?", help="Additional metadata for frame (as a python dict)")
        subparser.add_argument("-t", "--timestring", dest="timestring", default="", nargs="?", help="Python strptime() expression to decode timestamp with")
    
    def import_frame(self, filename, metadata = {}, template = ""):
        import SimpleSeer.models as M
        frame = M.Frame()
        frame.metadata['filename'] = filename
        if template:
            to_match = filename
            if not self.options.withpath:
                to_match = os.path.basename(filename) 
            match = re.match(template, to_match)
            metadata.update(match.groupdict())
        
        if metadata.get("time", False):
            timestring = metadata.pop('time')
            try:
                if self.options.timestring:
                    frame.capturetime = datetime.fromtimestamp(time.strptime(timestring, self.options.timestring))
                else:
                    frame.capturetime = parser.parse(timestring)
            except e:
                warnings.warn(e)
                frame.metadata['time'] = timestring
        
        if not frame.capturetime:
            frame.capturetime = datetime.fromtimestamp(os.stat(filename).st_mtime)
        
        if not metadata.get("camera", False):
            frame.camera = metadata.pop('camera')
        else:
            frame.camera = "File"
        
        frame.metadata.update(metadata)
        frame.image = Image(filename)
        frame.save()
        print "Imported {} at time {} for camera '{}' with attributes {}".format(filename, frame.capturetime, frame.camera, metadata)

    def run(self):
        from mongoengine import connection
        import SimpleSeer.models as M
        
        M.Frame._get_db().frame.ensure_index("metadata.filename")
        
        lastimport = 0
        if not self.options.all:
            metadata_params = { ("metadata__{}".format(k), v) for k, v in metadata.items() if k != 'camera' }
            if metadata.get('camera', False):
                metadata_params['camera'] = metadata['camera']
            lastframes = Frame.objects(metadata__filename__ne = "", **metadata_params).order_by(-createtime)
            if len(lastframes):
                lastimport = lastframes[0].capturetime.strftime('%s')
        
        metadata = {}
        if self.options.metadata:
            metadata = eval(self.options.metadata)
        
        def _expandTemplate(match):
            m = match.group(0)
            if m == '{time}':
                return "(?P<time>.?)"
            if m == '{camera}':
                return "(?P<camera>\w+)"
            else:
                return "(?P<" + m[1:-1] + ">.?)"
        
        template = ''
        if self.options.schema:
            template = r.sub(self.options.schema, _expandTemplate)
        
        if self.options.recursive:
            #this got a bit thick
            #walk the tree, match on our "files" glob, if the mtime > lastimport
            files = itertools.chain(
                *[[a+fname for fname in fnmatch.filter(c, self.options.files) if os.path.getmtime(a+fname) > lastimport]
                    for a, b, c in os.walk(self.options.dir)])
        else:
            files = glob.glob(os.path.join(self.options.dir, self.options.files))
        
        for f in files:
            if len(Frame.objects(metadata__filename = f, **metadata)):
                print "file {} already imported".format(f)
                continue
            
            self.import_frame(f, metadata, template)

class MRRCommand(Command):
    # Measurement repeatability and reproducability
    
    def __init__(self, subparser):
        subparser.add_argument("--filter", help="Frame filter query", default = '')
        
    def run(self):
        from SeerCloud.Control import MeasurementRandR
        from ast import literal_eval
        mrr = MeasurementRandR()

        query = []
        if self.options.filter:
            query = [literal_eval(self.options.filter)]

        df, deg = mrr.getData(query)
        repeat = mrr.repeatability(df, deg)
        repro = mrr.reproducability(df, deg)

        print '--- Repeatability ---'
        print repeat.to_string()

        print '--- Reproducability ---'
        print repro.to_string()
