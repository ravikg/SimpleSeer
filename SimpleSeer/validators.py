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
        if isinstance(value, dict):
            return value
        raise fev.Invalid('invalid Python dict', value, state)

class DateTime(fev.FancyValidator):

    def _to_python(self, value, state):
        try:
            return datetime.strptime(value, '%Y-%m-%dT%H:%M:%S.%fZ')
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

    def _to_python(self, value, state):
        from .Session import Session
        values = JSON()._to_python(value,None)
        settings = Session()
        import logging
        logger = logging.getLogger()
        try:
            schemakey = self.schemakey
            validators = settings.read_config()['modelschema'][schemakey]
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
        return retVal
    def _from_python(self, value, state):
        return value
