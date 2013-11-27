import os
import json
import shutil
import subprocess

import pkg_resources
from path import path
from paste.script.templates import Template, var
here = os.getcwd()
from .Session import Session


class SimpleSeerProjectTemplate(Template):
    _template_dir = 'paster_templates/seer_project'
    summary = 'SimpleSeer Installation Template'
    vars = [
        var('version', 'Version (like 0.1)',
            default='0.1'),
        var('description', 'One-line description of the package',
            default='SimpleSeer Project'),
        var('long_description', 'Multi-line description (in reST)',
            default='SimpleSeer Project'),
        var('keywords', 'Space-separated keywords/tags',
            default=''),
        var('author', 'Author name', default=''),
        var('author_email', 'Author email', default=''),
        var('url', 'URL of homepage', default=''),
        var('license_name', 'License name', default='Apache'),
        var('zip_safe', 'True/False: if the package can be distributed as a .zip file',
            default=False),
        ]

    def pre(self, command, output_dir, vars):
        base = pkg_resources.resource_filename(
            'SimpleSeer', 'static')
        base_esc = base.replace('/', '\\/')
        static = json.dumps({
                '/': (path(vars['package']) / 'static')})

        vars.update(
            brunch_base=base,
            brunch_base_app_regex='/^%s\/app/' % base_esc,
            brunch_base_vendor_regex='/^%s\/vendor/' % base_esc,
            static=static)

    def post(self, command, output_dir, vars):
        src_brunch = path(pkg_resources.resource_filename(
            'SimpleSeer', 'static'))
        src_templates = path(pkg_resources.resource_filename(
            'SimpleSeer', 'templates'))
        src_public = path(pkg_resources.resource_filename(
            'SimpleSeer', 'static/public'))
        tgt_brunch = (path(output_dir) / vars['package'] / 'brunch_src').abspath()
        tgt_templates = (path(output_dir) / vars['package'] / 'templates').abspath()
        tgt_public = (path(output_dir) / vars['package'] / 'static').abspath()
        # Ensure that brunch build has been run in the source
        with src_brunch:
            print subprocess.call(['brunch', 'build'])

        # Create package.json
        package = json.loads((src_brunch / 'package.json').text())
        package['name'] = vars['package']
        #print "creating package.json in {0}".format(tgt_brunch)
        (tgt_brunch / 'package.json').write_text(
            json.dumps(package, indent=2))

        # Copy (built) seer.js & seer.css
        dn = open("/dev/null")

        subprocess.call(['git','submodule','add', 'git@github.com:sightmachine/SimpleSeer.git', 'SimpleSeer'],stderr=dn)
        subprocess.call(['git','submodule','add', 'git@github.com:sightmachine/SeerCloud.git', 'SeerCloud'],stderr=dn)

        subprocess.call(['rm',tgt_brunch / 'vendor/javascripts/cloudtest.js'],stderr=dn)
        subprocess.call(['rm',tgt_brunch / 'vendor/javascripts/seertest.js'],stderr=dn)
        subprocess.call(['git','rm','--cached',tgt_brunch / 'vendor/javascripts/seer.js'],stderr=dn)
        subprocess.call(['git','rm','--cached',tgt_brunch / 'vendor/stylesheets/seer.css'],stderr=dn)
        subprocess.call(['git','rm','--cached','-r',tgt_public],stderr=dn)
        overwrite(
            src_public / 'javascripts/seer.js',
            tgt_brunch / 'vendor/javascripts/seer.js')
        overwrite(
            src_public / 'stylesheets/seer.css',
            tgt_brunch / 'vendor/stylesheets/seer.css')
        overwrite(
            src_public / 'javascripts/seertest.js',
            tgt_brunch / 'vendor/javascripts/seertest.js')
        overwrite(
            src_templates / 'index.html',
            tgt_templates / 'seer_index.html')
        overwrite(
            src_templates / 'testing.html',
            tgt_templates / 'testing.html')
        overwrite(
            src_templates / 'login.html',
            tgt_templates / 'login.html')


        # Copy image assets
        try:
            shutil.rmtree(tgt_brunch / 'app/assets/img/seer', True)
            shutil.copytree(
                src_brunch / 'app/assets/img/',
                tgt_brunch / 'app/assets/img/seer/')
        except OSError:
            pass

        # Build and copy cloud.js if applicable

        #TODO:
        # check to see if cloud exists
        # remove hardcoded path
        settings = Session(path(output_dir))
        if settings.in_cloud:
            cloud_brunch = path(pkg_resources.resource_filename('SeerCloud', 'static'))
            with cloud_brunch:
                print subprocess.call(['brunch', 'build'])
            overwrite(
                cloud_brunch / 'public/javascripts/cloud.js',
                tgt_brunch / 'vendor/javascripts/cloud.js')
            overwrite(
                cloud_brunch / 'public/stylesheets/cloud.css',
                tgt_brunch / 'vendor/stylesheets/cloud.css')
            overwrite(
                cloud_brunch / 'public/javascripts/cloudtest.js',
                tgt_brunch / 'vendor/javascripts/cloudtest.js')

            try:
                shutil.rmtree(tgt_brunch / 'app/assets/img/cloud', True)
                shutil.copytree(
                    cloud_brunch / 'app/assets/img/',
                    tgt_brunch / 'app/assets/img/cloud/')
            except OSError:
                pass


        # Link the app
        #with tgt_brunch:
        #    print subprocess.check_output(
        #        ['npm', 'link'])

        # Ensure that brunch build has been run in the target
        with tgt_brunch:
            print subprocess.call(['brunch', 'build'])


def overwrite(src, dst):
    if dst.exists(): dst.remove()
    if not dst.parent.exists(): dst.parent.makedirs()

    src.copy(dst)

def overlay(src, dst, force=False):
    for src_fn in src.walk():
        rel_fn = src.relpathto(src_fn)
        dst_fn = dst / rel_fn
        if src_fn.isdir():
            dst_fn.mkdir_p()
            continue
        if overwrite:
            overwrite(src_fn, dst_fn)
        else:
            src_fn.copy(dst_fn)
