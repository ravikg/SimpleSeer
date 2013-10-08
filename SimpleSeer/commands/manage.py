from .base import Command
import os
import os.path
import glob
import sys
import pkg_resources
import subprocess
import time
import re
from path import path
from SimpleSeer.Session import Session
from SimpleSeer.models import Alert
from socket import gethostname
from contextlib import closing
from zipfile import ZipFile, ZIP_DEFLATED
import time
import shutil

class ManageCommand(Command):
    "Simple management tasks that don't require SimpleSeer context"
    use_gevent = False

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
    "Deploy supervisor configuration"

    supervisor_dir  = "/etc/supervisor/conf.d/"
    supervisor_link = "/etc/supervisor/conf.d/simpleseer.conf"

    deploy_local_sub_reqs = ["mongodb", "rabbitmq"]
    deploy_local_seer_reqs = ["core", "olap", "worker", "web", "monitor"]
    deploy_local_kiosk_reqs = ["browser"]

    deploy_skybox_sub_reqs = ["mongodb", "rabbitmq"]
    deploy_skybox_seer_reqs = ["olap", "worker", "web", "monitor"]
    deploy_skybox_kiosk_reqs = []

    def __init__(self, subparser):
        subparser.add_argument("type", help="Deployment Type (local, skybox)", default = "local", nargs = '?')
        subparser.add_argument("directory", help="Target", default = os.path.realpath(os.getcwd()), nargs = '?')

    def run(self):
        link = "/etc/simpleseer"
        if os.path.lexists(link):
            os.remove(link)

        supervisor_link = self.supervisor_link
        if os.path.lexists(supervisor_link):
            os.remove(supervisor_link)

        regular_supervisor = "supervisor.conf"
        src_etc = path(self.options.directory) / 'etc'
        src_supervisor = src_etc / regular_supervisor
        src_paster = path(pkg_resources.resource_filename('SimpleSeer', 'paster_templates'))
        src_paster_etc = src_paster / 'seer_project' / 'etc'

        link_count = len(glob.glob(src_etc / "supervisor_*.conf"))
        if link_count is 0:
            print "**************************************************"
            print "* Error: No Supervisor Program files detected."
            print "* Copy them from SimpleSeer with the following command:"
            print "*   cp {} {}".format(src_paster_etc / "supervisor_*.conf", src_etc)
            print "* Please remove all program and group entries from supervisor.conf"
            print "**************************************************"
            return 0

        subsystem_reqs = self.deploy_local_sub_reqs
        simpleseer_reqs = self.deploy_local_seer_reqs
        kiosk_reqs = self.deploy_local_kiosk_reqs
        if self.options.type == "skybox":
            subsystem_reqs = self.deploy_skybox_sub_reqs
            simpleseer_reqs = self.deploy_skybox_seer_reqs
            kiosk_reqs = self.deploy_skybox_kiosk_reqs

        supervisor_groups  = "[group:subsystem]"
        supervisor_groups += "\nprograms={}".format(','.join(subsystem_reqs))
        supervisor_groups += "\n\n[group:seer]"
        supervisor_groups += "\nprograms={}".format(','.join(simpleseer_reqs))
        supervisor_groups += "\n\n[group:kiosk]"
        supervisor_groups += "\nprograms={}".format(','.join(kiosk_reqs))

        print "Linking %s to %s" % (self.options.directory, link)
        os.symlink(self.options.directory, link)

        hostname = gethostname()
        hostname_supervisor_filename = hostname + "_supervisor.conf"
        src_host_specific_supervisor = path(self.options.directory) / 'etc' / hostname_supervisor_filename

        src_supervisor_groups = src_etc / 'supervisor_group.conf'
        if os.path.lexists(src_supervisor_groups):
            os.remove(src_supervisor_groups)

        # The [group:*] blocks
        file_supervisor_groups = os.open(src_supervisor_groups, os.O_RDWR | os.O_CREAT)
        os.write(file_supervisor_groups, supervisor_groups)
        os.close(file_supervisor_groups)

        if os.path.exists(src_host_specific_supervisor):
            src_supervisor = src_host_specific_supervisor

        for file in glob.glob(self.supervisor_dir + "*_supervisor_*.conf"):
            os.remove(file)

        print "Linking %s to %s" % (src_supervisor, supervisor_link)
        os.symlink(src_supervisor, supervisor_link)

        for requirement in (subsystem_reqs + simpleseer_reqs + kiosk_reqs + ['group']):
            # Order helps order the program files so that
            # the 'group' file is the last to be imported
            # to supervisor.
            order = 1
            if requirement == 'group':
                order = 2
            src_reqconf = "{}/supervisor_{}.conf".format(src_etc, requirement)
            dest_reqconf = "{}{}_supervisor_{}.conf".format(self.supervisor_dir, order, requirement)
            print "Linking %s to %s" % (src_reqconf, dest_reqconf)
            os.symlink(src_reqconf, dest_reqconf)

        print "Reloading supervisord"
        subprocess.check_output(['supervisorctl', 'reload'])


class ServiceCommand(ManageCommand):


    def __init__(self, subparser):
        subparser.add_argument("verb", help="what you want to do with services: [list,add,remove]")
        subparser.add_argument("service", help="command you want to run with supervisor", default = "", nargs = '?')
        subparser.add_argument("args", help="arguments to the command", default = "", nargs = '?')

        subparser.add_argument("--logsize", help="maximum size for the service log file to attain eg 200MB, 2G", default="200MB", nargs="?")
        subparser.add_argument("--noautostart", help="don't start up automatically with supervisord", default=False, action="store_true")


    def _get_group(self, service):
        if service in ['mongodb', 'broker']:
            return 'subsystem'
        elif service in ['browser']:
            return 'kiosk'
        else:
            return 'seer'

    def run(self):
        if not self.options.verb in ['list', 'deploy', 'remove']:
            self.options.verb = 'list'

        if not os.path.exists(DeployCommand.supervisor_link):
            print "You need to run 'simpleseer deploy' before you can manage services"
            return

        import ConfigParser
        cp = ConfigParser.RawConfigParser()
        cp.read(DeployCommand.supervisor_link)

        need_write = False

        if self.options.verb == 'list':
            print "simpleseer services installed:"
            for program in [k for k in cp.sections() if re.match("program", k)]:
                print "\t{} autostart={} log size={}".format(program, dict(cp.items(program)).get('autostart', "False"), dict(cp.items(program)).get('stdout_logfile_maxbytes', "N/A"))

            print "\nsimpleseer service groups:"
            for group in [k for k in cp.sections() if re.match("group", k)]:
                print "\t{} programs={}".format(group, cp.get(group, 'programs'))

        section = "program:" + self.options.service
        group = "group:" + self._get_group(self.options.service)

        if self.options.verb == 'deploy':
            if not self.options.service:
                print 'you must specify a service to deploy'
                return

            template = dict(
                process_name = "%(program_name)s",
                priority = "30",
                redirect_stderr = "True",
                directory = "/etc/simpleseer",
                stdout_logfile = "/var/log/simpleseer.{}.log".format(self.options.service),
                startsecs = "5",
            )

            if cp.has_section(section):
                print "updating service {}".format(self.options.service)
                template = dict(cp.items(section))
            else:
                cp.add_section(section)

            section_options = template
            section_options['command'] = "/usr/local/bin/simpleseer -c /etc/simpleseer -l /etc/simpleseer/simpleseer-logging.cfg {} {}".format(self.options.service, self.options.args)
            section_options['autostart'] = str(not self.options.noautostart)
            section_options['stdout_logfile_maxbytes'] = self.options.logsize

            for k, v in section_options.items():
                cp.set(section, k, v)

            old_group_value = cp.get(group, "programs")
            group_list = [programs for programs in old_group_value.split(",") if programs != self.options.service]
            group_list.append(self.options.service)
            new_group_value = ",".join(group_list)
            cp.set(group, "programs", new_group_value)

            need_write = True


        if self.options.verb == 'remove':
            if not self.options.service:
                print "you must specify a service to remove"
                return


            if not cp.has_section(section):
                print "no service {} is installed, so can't do anything"
                return

            cp.remove_section(section)
            print "removed {} from services".format(section)


            old_group_value = cp.get(group, "programs")
            new_group_value = ",".join([programs for programs in old_group_value.split(",") if programs != self.options.service])
            cp.set(group, "programs", new_group_value)
            print "removed {} from {}".format(self.options.service, group)


            need_write = True

        if need_write:
            conf_file = "etc/" + gethostname() + "_supervisor.conf"

            print "writing config to {}".format(conf_file)
            conf = open(conf_file, 'w')
            cp.write(conf)
            conf.close()
            print "\nrun 'simpleseer deploy' as root to restart services and update symlink"




class GenerateDocsCommand(ManageCommand):
    def __init__(self, subparser):
       pass

    def run(self):
        libs = ['SimpleSeer', 'SeerCloud']
        for i in libs:
            coffeePath = path(pkg_resources.resource_filename(i, 'static/app'))
            docPath = path(pkg_resources.resource_filename(i, 'docs'))
            for root, subFolders, files in os.walk(coffeePath):
                _dp = root.replace(coffeePath,docPath)
                if not os.path.exists(_dp):
                    os.makedirs(_dp)
                try:
                    for file in files:
                        if file.find(".coffee") > -1:
                            thePlace = "{}/{}".format(root, file);
                            print subprocess.check_output(['docco', thePlace, '--layout linear', '--output', _dp])
                except:
                    print "Error running docco.  You may need to do the following:"
                    print "sudo npm install -g docco"
                    print "sudo pip install pygments"


class WatchCommand(ManageCommand):
    def __init__(self, subparser):
        subparser.add_argument("--refresh", help="send refresh signal to simpleseer on build", default=0)

    def run(self):
        settings = Session(self.options.config)
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
        anythingBuilt = False
        while True:
            anythingBuilt = False
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
                anythingBuilt = True

            if len(local_event_handler.eventqueue):
                time.sleep(0.2)
                with tgt_brunch:
                    print "Updating " + cwd
                    print subprocess.check_output(['brunch', 'build'])
                local_event_handler.eventqueue = []
                anythingBuilt = True

            if anythingBuilt is True and self.options.refresh != 0:
                Alert.redirect("@rebuild")

            time.sleep(0.5)


class WorkerCommand(Command):
    '''
    This Starts a distributed worker object using the celery library.

    Run from the the command line where you have a project created.

    >>> simpleseer worker


    The database the worker pool queue connects to is the same one used
    in the default configuration file (simpleseer.cfg).  It stores the
    data in the default collection 'celery'.

    To issue commands to a worker, basically a task master, you run:

    >>> simpleseer shell
    >>> from SimpleSeer.command.worker import update_frame
    >>> for frame in M.Frame.objects():
          update_frame.delay(str(frame.id))
    >>>

    That will basically iterate through all the frames, if you want
    to change it then pass the frame id you want to update.

    '''
    use_gevent = False

    def __init__(self, subparser):
        subparser.add_argument("--purge", help="clear out the task queue", action="store_true")

    def run(self):

        # Subscribe to heartbeat
        self.heartbeat(name="worker")

        if self.options.purge:
            cmd = ('celery', 'purge', '--config', 'SimpleSeer.celeryconfig')
            subprocess.call(cmd)
            print " ".join(cmd)
            print "Task queue purged"
        else:
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

@ManageCommand.simple()
def BaseCommand(self):
    subprocess.call(['sh', 'SimpleSeer/scripts/base.sh'])
    BuildCommand("").run()

