from copy import deepcopy

import mongoengine
from formencode import validators as fev
from formencode import schema as fes
import formencode as fe

from SimpleSeer import validators as V
from SimpleSeer import util

from .base import SimpleDoc


class DashboardSchema(fes.Schema):
    name = fev.UnicodeString(not_empty=True)
    widgets = fev.Set(if_empty=[], if_missing=[])

class Dashboard(SimpleDoc, mongoengine.Document):
    name = mongoengine.StringField()
    widgets = mongoengine.ListField(mongoengine.DictField())

    def __repr__(self):
      return "[%s Object <%s> ]" % (self.__class__.__name__, self.name)
