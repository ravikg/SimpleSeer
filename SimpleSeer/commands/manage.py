from .base import Command
import os
import os.path
import sys
import pkg_resources
import subprocess
import time
from path import path
from SimpleSeer.Session import Session
from socket import gethostname
from contextlib import closing
from zipfile import ZipFile, ZIP_DEFLATED
import time
import shutil


class ManageCommand(Command):
    "Simple management tasks that don't require SimpleSeer context"
    use_gevent = False
    remote_seer = False

    def configure(self, options):
        self.options = options
    
class CreateCommand(ManageCommand):
    "Create a new repo"
    
    def __init__(self, subparser):
        subparser.add_argument("projectname", help="Name of new project")
        
    def run(self):
        from paste.script import command as pscmd
        pscmd.run(["create", "-t", "simpleseer", self.options.projectname])


class ResetCommand(ManageCommand):
    "Clear out the database"
    
    def __init__(self, subparser):
        subparser.add_argument("database", help="Name of database", default="default", nargs='?')

    #TODO, this should probably be moved to a pymongo command and include a supervisor restart all
    def run(self):
        print "This will destroy ALL DATA in database \"%s\", type YES to proceed:"
        if sys.stdin.readline() == "YES\n":
            os.system('echo "db.dropDatabase()" | mongo ' + self.options.database)
        else:
            print "reset cancelled"

class BackupCommand(ManageCommand):
    "Backup the existing database"

    def __init__(self, subparser):
       pass


    def run(self):
        sess = Session(os.getcwd())        
        filename = sess.database + "-backup-" + time.strftime('%Y-%m-%d-%H_%M_%S')
        subprocess.call(['mongodump','--db',sess.database,'--out',filename])
        print 'Backup saved to directory:', filename
        exit()
        

class DeployCommand(ManageCommand):
    "Deploy an instance"
    def __init__(self, subparser):
        subparser.add_argument("directory", help="Target", default = os.path.realpath(os.getcwd()), nargs = '?')

    def run(self):
        link = "/etc/simpleseer"
        if os.path.lexists(link):
            os.remove(link)
            
        supervisor_link = "/etc/supervisor/conf.d/simpleseer.conf"
        if os.path.lexists(supervisor_link):
            os.remove(supervisor_link)
            
        print "Linking %s to %s" % (self.options.directory, link)
        os.symlink(self.options.directory, link)
        
        

        hostname = gethostname()
        hostname_supervisor_filename = hostname + "_supervisor.conf"
        src_host_specific_supervisor = path(self.options.directory) / 'etc' / hostname_supervisor_filename
        
        regular_supervisor = "supervisor.conf"
        src_supervisor = path(self.options.directory) / 'etc' / regular_supervisor
        
        
        if os.path.exists(src_host_specific_supervisor):
            src_supervisor = src_host_specific_supervisor
            
        print "Linking %s to %s" % (src_supervisor, supervisor_link)
        os.symlink(src_supervisor, supervisor_link)
        
        print "Reloading supervisord"
        subprocess.check_output(['supervisorctl', 'reload'])



@ManageCommand.simple()
def WatchCommand(ManageCommand):
    settings = Session(ManageCommand.options.config)
    cwd = os.path.realpath(os.getcwd())
    package = cwd.split("/")[-1]

    src_brunch = path(pkg_resources.resource_filename(
        'SimpleSeer', 'static'))
    tgt_brunch = path(cwd) / package / 'brunch_src'
    
    if settings.in_cloud:
        cloud_brunch = path(pkg_resources.resource_filename('SeerCloud', 'static'))
    
    BuildCommand("").run()
    #run a build first, to make sure stuff's up to date
    
    
    #i'm not putting this in pip, since this isn't necessary in production
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
    
    #Event watcher for SimpleSeer
    seer_event_handler = FileSystemEventHandler()
    seer_event_handler.eventqueue = []
    def rebuild(event):
        seer_event_handler.eventqueue.append(event)
    
    seer_event_handler.on_any_event = rebuild
    
    seer_observer = Observer()
    seer_observer.schedule(seer_event_handler, path=src_brunch, recursive=True)
    
    #Event watcher for SeerCloud
    if settings.in_cloud:
        cloud_event_handler = FileSystemEventHandler()
        cloud_event_handler.eventqueue = []
        def build_cloud(event):
            cloud_event_handler.eventqueue.append(event)
    
        cloud_event_handler.on_any_event = build_cloud
    
        cloud_observer = Observer()
        cloud_observer.schedule(cloud_event_handler, path=cloud_brunch, recursive=True)
    
    #Event watcher for seer application
    local_event_handler = FileSystemEventHandler()
    local_event_handler.eventqueue = []
    
    def build_local(event):
        local_event_handler.eventqueue.append(event)
        
    local_event_handler.on_any_event = build_local
    
    local_observer = Observer()
    local_observer.schedule(local_event_handler, path=tgt_brunch, recursive=True)
    
    seer_observer.start()
    if settings.in_cloud:
        cloud_observer.start()
    local_observer.start()
        
    ss_builds = 0
    while True:
        ss_builds += len(seer_event_handler.eventqueue)
        try:
            ss_builds += len(cloud_event_handler.eventqueue)
        except UnboundLocalError:
            pass

        if ss_builds:
            time.sleep(0.2)
            BuildCommand("").run()
            time.sleep(0.1)
            seer_event_handler.eventqueue = []
            try:
                cloud_event_handler.eventqueue = []
            except UnboundLocalError:
                pass
            local_event_handler.eventqueue = []
            ss_builds = 0
        
        if len(local_event_handler.eventqueue):
            time.sleep(0.2)
            with tgt_brunch:
                print "Updating " + cwd
                print subprocess.check_output(['brunch', 'build'])
            local_event_handler.eventqueue = []
                
        time.sleep(0.5)


@ManageCommand.simple()
def WorkerCommand(self):
        import socket
        worker_name = socket.gethostname() + '-' + str(time.time())
        cmd = ['celery','worker','--config',"SimpleSeer.celeryconfig",'-n',worker_name]
        print " ".join(cmd)
        subprocess.call(cmd)

@ManageCommand.simple()
def BuildCommand(self):
    "Rebuild CoffeeScript/brunch in SimpleSeer and the process"
    import SimpleSeer.template as sst
    cwd = os.path.realpath(os.getcwd())
    print "Updating " + cwd
    sst.SimpleSeerProjectTemplate("").post("", cwd, { "package": cwd.split("/")[-1] })
