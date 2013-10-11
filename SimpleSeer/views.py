import os
import re
import json
import logging
import calendar
from datetime import datetime
from cStringIO import StringIO
import hashlib

import bson.json_util
import gevent
import coffeescript
from socketio import socketio_manage
from flask import request, make_response, Response, redirect, render_template
import flask

from . import models as M
from . import util
from .realtime import RealtimeNamespace, ChannelManager
from .Session import Session
from .Filter import Filter
from flask import Flask, request, render_template, redirect, url_for, flash
from flask.ext.login import (current_user, login_required,
                              login_user, logout_user, confirm_login,
                              fresh_login_required)

log = logging.getLogger()
session = Session()

def checkLoginRequired(func):
  if session.requireAuth:
    res = login_required(func)
  else:
    res = func
  return res

class route(object):
    routes = []

    def __init__(self, path, **kwargs):
        self.path, self.kwargs = path, kwargs

    def __call__(self, func):
        self.routes.append(
            (func, self.path, self.kwargs))
        return func

    @classmethod
    def register_routes(cls, app):
        for func, path, kwargs in cls.routes:
            app.route(path, **kwargs)(func)

@route('/socket.io/<path:path>')
@checkLoginRequired
def sio(path):
    socketio_manage(
        request.environ,
        {'/rt': RealtimeNamespace },
        request._get_current_object())

@route('/')
@checkLoginRequired
def index():
    files= ["javascripts/app.js","javascripts/vendor.js","stylesheets/app.css"]
    baseUrl = ''
    MD5Hashes = {}
    settings = Session().get_config()
    if settings.get('in_cdn',False):
        baseUrl = "http://cdn.demo.sightmachine.com/"
    for f in files:
      fHandler = open("{0}/{1}".format(settings['web']['static']['/'],f), 'r')
      m = hashlib.md5()
      m.update(fHandler.read())
      MD5Hashes[baseUrl+f] = dict(path=m.hexdigest(),type=f.rsplit(".")[1])
      print MD5Hashes
    return render_template("index.html",params = dict(MD5Hashes=MD5Hashes),settings=settings)

@route('/testing')
@checkLoginRequired
def testing():
    return render_template("testing.html", settings=settings)

@route('/log/<type>', methods=['POST'])
@checkLoginRequired
def jsLogger(type):
    levels = {"CRITICAL":50, "ERROR":40, "WARNING":30, "INFO":20, "DEBUG":10}
    type = type.upper()
    if type in levels:
        import logging
        logger = logging.getLogger()
        logger.log(levels[type],request.values.to_dict())
        return 'ok'
    return 'invalid arguments'

@route('/context/<name>', methods=['GET'])
@util.jsonify
@checkLoginRequired
def getContext(name):
    context = M.Context.objects(name = name)
    if context:
        return context[0]
    else:
        return None

@route('/plugins.js')
@checkLoginRequired
def plugins():

    useCache = False
    if os.path.exists('./cached.js'):
        cacheTime = os.path.getmtime('./cached.js')

        useCache = True
        for ptype, plugins in util.all_plugins().items():
            for name, plugin in plugins.items():
                stem = plugin.__name__.split('.')[-1]
                plugin_path = __import__(plugin.__module__).__file__
                s = plugin_path.split('/')
                plugin_path = plugin_path[0:len(plugin_path)-len(s[-1])] #pull of the filename
                plugin_path = plugin_path + "plugins/"+stem+"/cs/"+stem #add the plugin name
                mpath = plugin_path+"Inspection.coffee"
                if os.path.exists(mpath):
                    plugTime = os.path.getmtime(mpath)
                    if plugTime > cacheTime:
                        useCache = False

    if not useCache:
        result = []
        for ptype, plugins in util.all_plugins().items():
            for name, plugin in plugins.items():
                #print plugin.__name__, name
                if 'coffeescript' in dir(plugin):
                    for requirement, cs in plugin.coffeescript():
                        #result.append('(function(plugin){')
                        pluginType = requirement.split('/')[1]
                        if True:
                            result.append("window.require.define({{\"plugins/{0}/{1}\": function(exports, require, module) {{(function() {{".format(pluginType,name))
                            try:
                                result.append(coffeescript.compile(cs, True))
                            except Exception, e:
                                print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                                print "COFFEE SCRIPT ERROR"
                                print e
                                print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                            #result.append('}).call(require(%r), require("lib/plugin"));\n' % requirement)
                            result.append("}).call(this);}});")
        js = "\n".join(result)
        f = open('./cached.js', 'w')
        log.info('Writing new javascript cache')
        f.write(js)
    else:
        f = open('./cached.js', 'r')
        log.info('Reading javascript from cache')
        js = f.read()

    resp = make_response(js, 200)
    resp.headers['Content-Type'] = "text/javascript"
    return resp

@route('/test', methods=['GET', 'POST'])
def test():
    return 'This is a test of the emergency broadcast system'

@route('/test.json', methods=['GET', 'POST'])
@route('/_test', methods=['GET', 'POST'])
def test_json():
    return 'This is a test of the emergency broadcast system'

@route('/frames', methods=['GET'])
@util.jsonify
@checkLoginRequired
def frames():
    params = request.values.to_dict()
    f_params = json.loads(
        params.get('filter', '[]'),
        object_hook=util.object_hook)
    s_params = json.loads(
        params.get('sort', '[]'),
        object_hook=util.object_hook)
    skip = int(params.get('skip', 0))
    limit = int(params.get('limit', 20))
    total_frames, frames, earliest_date = M.Frame.search(f_params, s_params, skip, limit)
    if earliest_date:
        earliest_date = calendar.timegm(earliest_date.timetuple())
    return dict(frames=frames, total_frames=total_frames, earliest_date=earliest_date)

@route('/getFrames/<filter_params>', methods=['GET'])
@util.jsonify
@checkLoginRequired
def getFrames(filter_params):
    log.warn("API endpoint getFrames/ is DEPRECATED")
    from .base import jsondecode
    from HTMLParser import HTMLParser
    from SeerCloud.OLAPUtils import OLAPFactory

    # filter_params should be in the form of a json encoded dicts
    # that probably was also html encoded
    p = HTMLParser()
    nohtml = str(p.unescape(filter_params))
    params = jsondecode(nohtml)

    skip = int(params.get('skip', 0))
    limit = params.get('limit', None)
    if limit:
        limit = int(limit)
    else:
        log.info('No limit set.  Using 50k to prevent mongo errors')
        limit = 50000

    sortinfo = params.get('sortinfo', {})
    groupByField = params.get('groupByField',{})
    query = params['query']

    f = Filter()
    total_frames, frames = f.getFrames(query, limit=limit, skip=skip, sortinfo=sortinfo, groupByField=groupByField)
    #frames = OLAPFactory.filterToOLAP(query, limit=limit, skip=skip, sortinfo=sortinfo)
    retVal = dict(frames=frames, total_frames=-1)


    if retVal:
        return retVal
    else:
        return {frames: None, 'error': 'no result found'}

@route('/downloadFrames', methods=['GET', 'POST'])
@checkLoginRequired
def downloadFrames():
    from .base import jsondecode

    params = request.values.to_dict()
    rawdata = jsondecode(params['rawdata'])
    result_format = params['format']

    f = Filter()

    if result_format == 'csv':
        resp = make_response(f.toCSV(rawdata), 200)
        resp.headers['Content-Type'] = 'text/csv'
        resp.headers['Content-disposition'] = 'attachment; filename="frames.%s.csv"' % str(datetime.now())
    elif result_format == 'excel':
        resp = make_response(f.toExcel(rawdata), 200)
        resp.headers['Content-Type'] = 'application/vnd.ms-excel'
        resp.headers['Content-disposition'] = 'attachment; filename="frames.%s.xls"' % str(datetime.now())
    else:
        return 'Unknown format', 404
    return resp

@route('/getFilter/<filter_type>/<filter_name>/<filter_format>', methods=['GET'])
@util.jsonify
@checkLoginRequired
def getFilter(filter_type, filter_name, filter_format):

    # formats: numeric, string, autofill, datetime
    # types: measurement, frame, framefeature

    f = Filter()
    retVal = f.checkFilter(filter_type, filter_name, filter_format)

    if retVal:
        return retVal
    else:
        return {'error': 'no result found'}

@route('/features', methods=['GET'])
@checkLoginRequired
@util.jsonify
def features():
    f = Filter()
    return f.getFilterOptions()

#TODO, abstract this for layers and thumbnails
@route('/grid/imgfile/<frame_id>', methods=['GET'])
@checkLoginRequired
def imgfile(frame_id):
    params = request.values.to_dict()
    frame = M.Frame.objects(id = bson.ObjectId(frame_id))
    if not frame or not frame[0].imgfile:
        return "Image not found", 404
    frame = frame[0]
    resp = make_response(frame.imgfile.read(), 200)
    resp.headers['Content-Type'] = frame.imgfile.content_type
    if 'download' in params:
        resp.headers['Content-disposition'] = 'attachment; filename="%s-%s.jpg"' % \
            (frame.camera.replace(' ','_'), frame.capturetime.strftime("%Y-%m-%d_%H_%M_%S"))

    return resp

#TODO, abstract this for layers and thumbnails
@route('/grid/thumbnail_file/<frame_id>', methods=['GET'])
@checkLoginRequired
def thumbnail(frame_id):
    params = request.values.to_dict()
    frame = M.Frame.objects(id = bson.ObjectId(frame_id))
    if not frame or not frame[0].imgfile:
        return "Image not found", 404
    frame = frame[0]

    if not frame.thumbnail_file:
        t = frame.thumbnail
        if not "is_slave" in Session().mongo or not Session().mongo['is_slave']:
            frame.save(publish = False)
        else:
            s = StringIO()
            t.save(s, "jpeg", quality = 75)
            resp = make_response(s.getvalue(), 200)
            resp.headers['Content-Type'] = "image/jpeg"
            return resp

    resp = make_response(frame.thumbnail_file.read(), 200)
    resp.headers['Content-Type'] = frame.thumbnail_file.content_type
    return resp

@route('/ping', methods=['GET', 'POST'])
@util.jsonify
def ping():
    text = "pong"
    return {"text": text }

#todo: move settings to mongo, create model with save
@route('/settings', methods=['GET', 'POST'])
@util.jsonify
def settings():
    util.ensure_plugins()
    text = Session().get_config()
    plugins = {'Inspection':[],'Measurement':[],'Watcher':[]}
    for i in plugins:
        try:
            plugins[i] =  [o for o in eval("M.{0}._plugins".format(i))]
        except AttributeError:
            pass
    return {"settings": text, "plugins":plugins }

@route('/_status', methods=['GET', 'POST'])
def status():
    import json
    from SeerCloud.commands.monitor import Health
    response = {'message':'default', 'status': 200}
    response = Health().health()
    resp = make_response(json.dumps(response['message']), response['status'])
    return resp

@route('/_statusJSON', methods=['GET', 'POST'])
def statusJSON():
    # Callback is to support the Cross Domain 'JSONP' request.
    return format(request.values['callback']) + "({status: 200})"

@route('/_auth', methods=['GET','POST'])
@util.jsonify
def auth():
    if flask.ext.login.current_user.is_authenticated():
        secureUserDict = {}
        user = M.User.objects(username=flask.ext.login.current_user.name)[0]
        for key in [key for key in user if key != "password"]:
            secureUserDict[key] = user[key]
        return {"authed": True, "user": secureUserDict}
    return {"authed": False}

@route('/login', methods=["GET", "POST"])
def login():
  from .Web import User
  settings = Session().get_config()
  is_post = bool(request.method == "POST")
  has_username = bool("username" in request.form)

  if is_post and has_username:
    username = request.form["username"]
    password = request.form["password"]
    remember = bool(request.form.get("remember", "no") == "yes")

    try:
        query = M.User.objects.get(username=username)
        # Preforms a match in the model, using the salt.
        if query.checkPassword(password):
            user = User(query)
            if login_user(user, remember=remember):
              return redirect(request.args.get("next") or url_for("index"))
            else:
              flash("An unknown error occured.")
              flash("Please contact the system administrator.")
        else:
            flash(u"Invalid username / password.")
    except:
        flash(u"Invalid username / password.")

  return render_template("login.html", settings = settings)

@route("/reauth", methods=["GET", "POST"])
@login_required
def reauth():
    if request.method == "POST":
        confirm_login()
        return redirect(request.args.get("next") or url_for("index"))
    return render_template("reauth.html")

@route("/logout")
@login_required
def logout():
  logout_user()
  return redirect(url_for("index"))

@route('/execute/<frame_id>', methods=['GET'])
@checkLoginRequired
def re_measure(frame_id):
    params = request.values.to_dict()
    frame = M.Frame.objects(id = bson.ObjectId(frame_id))
    if not frame:
        return "Frame not found", 404
    frame = frame[0]
    frame.save(execute = True)
    resp = make_response('OK', 200)
    return resp
