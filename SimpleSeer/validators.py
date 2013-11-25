from datetime import datetime

import bson
from formencode import validators as fev
from formencode import api as fevapi
from formencode import Invalid

class ObjectId(fev.FancyValidator):

    def _to_python(self, value, state):
        if value is None: return None
        try:
            return bson.ObjectId(value)
        except bson.InvalidId:
            raise fev.Invalid('invalid object id', value, state)

    def _from_python(self, value, state):
        if value is None: return None
        return str(value)

class JSON(fev.FancyValidator):

    def _to_python(self, value, state):
        if value is None: return None
        if isinstance(value, dict) or isinstance(value, list):
            return value
        raise fev.Invalid('invalid JSON document', value, state)

    def _from_python(self, value, state):
        if value is None: return None
        if isinstance(value, dict) or isinstance(value, list):
            return value
        raise fev.Invalid('invalid Python dict', value, state)

class DateTime(fev.FancyValidator):

    def _to_python(self, value, state):
        try:
            try:
                return datetime.strptime(value, '%Y-%m-%dT%H:%M:%S.%fZ')
            except ValueError:
                return datetime.strptime(value, '%Y-%m-%d %H:%M:%S.%f')
        except ValueError, ve:
            raise fev.Invalid(str(ve), value, state)

    def _from_python(self, value, state):
        return value.strftime('%Y-%m-%dT%H:%M:%S.%fZ')

"""
example of modelschema in simpleseer.cfg (all args are optional)
modelschema:
  metadata:
    "Part ID":
      validator: 'string'
      args:
        if_empty: ""
        if_missing: ""
        if_invalid: ""
    "User Name":
      validator: 'regex'
      args:
        regex: "^[a-zA-Z]+$"
"""
class StrictJSON(fev.FancyValidator):
    validatorMap = {'string':fev.UnicodeString,'json':JSON,'datetime':DateTime,'objectid':ObjectId, 'list':fev.Set, 'int':fev.Int, 'bool':fev.Bool, 'regex':fev.Regex}

    def _to_python(self, value, state=None):
        from .Session import Session
        values = JSON()._to_python(value,None)
        settings = Session()
        import logging
        logger = logging.getLogger()
        try:
            schemakey = self.schemakey
            validators = settings.get_config()['modelschema'][schemakey]
        except AttributeError:
            logger.warn("No matchKey for custom schema in StrictJSON validator")
            return {} if self.if_missing == fevapi.NoDefault else self.if_missing 
        except KeyError:
            logger.warn("no modelschema key \"{0}\" found in simpleseer config".format(schemakey))
            return {} if self.if_missing == fevapi.NoDefault else self.if_missing 
        retVal = {}
        for _k, _v in values.iteritems():
            ref = validators.get(_k,None)
            if ref:
                mappedItem = self.validatorMap.get(ref['validator'],None)
                if mappedItem:
                    kwargs = ref.get('args',{})
                    try:
                        retVal[_k] = mappedItem(**kwargs).to_python(_v,None)
                    except Invalid:
                        logger.info("Invalid value \"{0}\" in {1}.{2}".format(_v,schemakey,_k))
        for _k, _v in validators.iteritems():
            if_missing = _v.get("args",{}).get("if_missing",None)
            if if_missing and not retVal.get(_k,None):
                retVal[_k] = if_missing
        return retVal
    def _from_python(self, value, state):
        return value

class ReferenceFieldList(fev.FancyValidator):

    def _to_python(self, value, state):
        retVal = []
        for obj in value:
            if obj.get('id',None) == None:
                obj = self.ref_type(obj)
                obj.save()
                retVal.append(bson.ObjectId(obj['id']))
            elif obj.get("_DBRef__id",None):
                retVal.append(bson.ObjectId(obj['_DBRef__id']))
            else:
                retVal.append(bson.ObjectId(obj['id']))
        return retVal

    def _from_python(self, value, state):
        return value

class GridFSFile(fev.FancyValidator):

    def _from_python(self, value, state):
        if hasattr(value, 'grid_id'):
            if value.grid_id:
                return str(value.grid_id)
            else:
                return ''
        else:
            return ''
