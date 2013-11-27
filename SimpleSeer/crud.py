import bson
import formencode as fe
import flask
import flask_rest
from werkzeug import exceptions

from .base import jsonencode
from . import models as M
from . import validators as V

# SERIALIZERS expects and 'encode' property in its encoders
jsonencode.encode = jsonencode
flask_rest.SERIALIZERS['application/json'] = jsonencode

def register(app):
    bp = flask.Blueprint("api", __name__, url_prefix="/api")

    @bp.errorhandler(400)
    @bp.errorhandler(404)
    def errorhandler(error):
        result = getattr(error, 'description', {})
        if not isinstance(result, dict):
            result = dict(__error__=result)
        return flask.Response(
            jsonencode(result),
            status=error.code,
            mimetype='application/json')
            
        return error.description, error.code

    handlers = [
        ModelHandler(M.Inspection, M.InspectionSchema,
                     'inspection', '/inspection'),
        ModelHandler(M.Measurement, M.MeasurementSchema, 'measurement', '/measurement'),
        ModelHandler(M.Tolerance, M.ToleranceSchema, 'tolerance', '/tolerance'),
        ModelHandler(M.Frame, M.FrameSchema, 'frame', "/frame"),
        ModelHandler(M.FrameSet, M.FrameSetSchema, 'frameset', '/frameset'),
        ModelHandler(M.Context, M.ContextSchema, 'context', '/context')
        ]
    
    # Handlers for SeerCloud objects, if loaded
    if 'OLAP' in dir(M):
        handlers.append(ModelHandler(M.OLAP, M.OLAPSchema, 'olap', '/olap'))
    if 'Dashboard' in dir(M):
        handlers.append(ModelHandler(M.Dashboard, M.DashboardSchema, 'dashboard', '/dashboard'))
    if 'Chart' in dir(M):
        handlers.append(ModelHandler(M.Chart, M.ChartSchema, 'chart', '/chart'))
    if 'TabContainer' in dir(M):
        handlers.append(ModelHandler(M.TabContainer, M.TabContainerSchema, 'tabcontainer', '/tabcontainer'))
    if 'Truth' in dir(M):
        handlers.append(ModelHandler(M.Truth, M.TruthSchema, 'truth', '/truth'))
        
    for h in handlers:
        flask_rest.RESTResource(
            app=bp, name=h.name, route=h.route,
            actions= h.actions,
            handler=h)

    app.register_blueprint(bp)

class ModelHandler(object):

    def __init__(self, cls, schema, name, route,
                 actions = ("list", "add", "update", "delete", "get")):
        self._cls = cls
        self.schema = schema()
        self.name = name
        self.route = route
        self.actions = actions

    # get object by id or name
    def _get_object(self, id):
        from mongoengine import ValidationError
        try:
            id = bson.ObjectId(id)
        except bson.errors.InvalidId:
            if getattr(self._cls, 'name', None):
                objs = self._cls.objects(name=id)
            else:
                raise exceptions.NotFound('Invalid ObjectId')
        else:
            try:
                objs = self._cls.objects(id=id)
            except ValidationError:
                raise exceptions.NotFound('Invalid ObjectId')

        if not objs:
            raise exceptions.NotFound('Object not found')
        return objs[0]

    def _get_body(self, body):
        # Ignore backbone's version control keys, which are in the form of numbers
        for key in body.keys():
            if key.isdigit():
                del body[key]

        try: # Is this a new model?
            id = body['id']
        except KeyError: # Good, then set a blank ID so our schema validator doesn't fail.
            body['id'] = None
            pass

        try:
            values = self.schema.to_python(body, None) # Validate our dict
            try:
                del values['results']
                del values['features']
                del values['id']
                del values['imgfile']
                del values['thumbnail_file']
            except KeyError:
                pass
        except fe.Invalid, inv:
            raise exceptions.BadRequest(inv.unpack_errors())
        return values

    def add(self):
        values = self._get_body(flask.request.json)
        obj = self._cls(**values)
        obj.save()
        return 201, obj

    def update(self, **kwargs):
        id = kwargs.values()[0]
        obj = self._get_object(id)
        values = self._get_body(flask.request.json)
        obj.update_from_json(values)
        obj.save()
        return 200, obj

    def delete(self, **kwargs):
        id = kwargs.values()[0]
        obj = self._get_object(id)
        d = obj.__getstate__()
        obj.delete()
        return 200, d

    def get(self, **kwargs):
        id = kwargs.values()[0]

        obj = self._get_object(id)
        to_validate = {}
        for x in self.schema.fields.keys():
            if hasattr(obj, x):
                to_validate[x] = obj[x]

        return 200, self.schema.from_python(to_validate)

    def list(self):
        objs = self._cls.objects()
        retVal = []
        for obj in objs:
            to_validate = {}
            for x in self.schema.fields.keys():
                to_validate[x] = obj[x]
            retVal.append(self.schema.from_python(to_validate))
        return 200, retVal