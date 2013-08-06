from cStringIO import StringIO
from calendar import timegm
import mongoengine
from mongoengine import signals as sig

from SimpleSeer.base import Image, pil, pygame
from SimpleSeer import util
from SimpleSeer.Session import Session

from formencode import validators as fev
from formencode import schema as fes
from SimpleSeer import validators as V
import formencode as fe

from .base import SimpleDoc, SONScrub
import mongoengine

from datetime import datetime
from pytz import timezone

class UserSchema(fes.Schema):
    allow_extra_fields=True
    filter_extra_fields=True
    name = fev.UnicodeString(not_empty=True)
    username = fev.UnicodeString(not_empty=True)
    password = fev.UnicodeString(not_empty=True)

class User(SimpleDoc, mongoengine.Document):
    name = mongoengine.StringField()
    username = mongoengine.StringField()
    password = mongoengine.StringField()

    def __init__(self, **kwargs):
        from .base import checkPreSignal, checkPostSignal
        from SimpleSeer.Session import Session
        super(User, self).__init__(**kwargs)

    def __repr__(self): # pragma no cover
        return "<SimpleSeer User Object '%s'>" % (self.username)

