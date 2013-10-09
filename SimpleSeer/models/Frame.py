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

from datetime import datetime
from pytz import timezone

from .base import SimpleDoc, SONScrub
from .FrameFeature import FrameFeature
from .Clip import Clip
from .Result import ResultEmbed
from .. import realtime
from ..util import LazyProperty


class FrameSchema(fes.Schema):
    allow_extra_fields=True
    filter_extra_fields=True
    capturetime = V.DateTime(if_missing=None)
    capturetime_epoch = fev.Int(if_empty=None, if_missing=None)
    updatetime = fev.UnicodeString(if_missing=None)
    localtz = fev.UnicodeString(if_missing='UTC')
    camera = fev.UnicodeString(if_missing='')
    features = fev.Set(if_empty=[], if_missing=[])
    results = fev.Set(if_empty=[], if_missing=[])
    height = fev.Int(if_empty=0, if_missing=0)
    width = fev.Int(if_empty=0, if_missing=0)
    metadata = V.JSON(if_empty={}, if_missing={})
    notes = fev.UnicodeString(if_empty="", if_missing="")
    #TODO, make this feasible as a formencode schema for upload


class Frame(SimpleDoc, mongoengine.Document):
    """
        Frame Objects are a mongo-friendly wrapper for SimpleCV image objects,
        containing additional properties for the originating camera and time of capture.

        Note that Frame.image property must be used as a getter-setter.

        >>> f = SimpleSeer.capture()[0]  #get a frame from the SimpleSeer module
        >>> f.image.dl().line((0,0),(100,100))
        >>> f.save()
        >>> 
    """
    capturetime = mongoengine.DateTimeField()
    capturetime_epoch = mongoengine.IntField(default = 0)
    updatetime = mongoengine.DateTimeField()
    localtz = mongoengine.StringField(default='UTC')
    camera = mongoengine.StringField()
    features = mongoengine.ListField(mongoengine.EmbeddedDocumentField(FrameFeature))
    results = mongoengine.ListField(mongoengine.EmbeddedDocumentField(ResultEmbed))
    
    height = mongoengine.IntField(default = 0)
    width = mongoengine.IntField(default = 0)
    clip_id = mongoengine.ObjectIdField(default=None)
    clip_frame = mongoengine.IntField(default=None)
    imgfile = mongoengine.FileField()
    thumbnail_file = mongoengine.FileField()
    metadata = mongoengine.DictField()
    notes = mongoengine.StringField(default='')
    _imgcache = ''
    _imgcache_dirty = False
    _recentframes = [] #class-wide frame cache for lastobjects()
    

    meta = {
        'indexes': ["capturetime", "camera", "-capturetime", ('camera', '-capturetime'), "-capturetime_epoch", "capturetime_epoch", "results", "results.state", "metadata"]
    }
    
    
    def __init__(self, **kwargs):
        from .base import checkPreSignal, checkPostSignal
        from SimpleSeer.Session import Session
        
        super(Frame, self).__init__(**kwargs)
        
        app = Session()._Session__shared_state['appname']
        
        for pre in Session().get_triggers(app, 'Frame', 'pre'):
            sig.pre_save.connect(pre, sender=Frame, weak=False)
        
        for post in Session().get_triggers(app, 'Frame', 'post'):
            sig.post_save.connect(post, sender=Frame, weak=False)
    
    @classmethod
    #which fields we care about for Filter.py
    def filterFieldNames(cls):
        return ['capturetime', 'capturetime_epoch', 'updatetime', 'localtz', 'camera', 'height', 
               'width', 'clip_id', 'clip_frame', 'imgfile', 'thumbnail_file', 'metadata', 'notes', 'results']


    @classmethod
    def lastobjects(self, **kwargs):
        if not Session().framebuffer:
            return Frame.objects(**kwargs).order_by("-capturetime")
        
        if not len(self._recentframes):
            self._recentframes.extend(list(Frame.objects.order_by("-capturetime").limit(Session().framebuffer)))
        
        subset = [frame for frame in self._recentframes]
        def valuecompare(frame, field, value):
            fields = field.split("__")
            operator = "eq"
            if fields[-1] in ["gt", "lt", "gte", "lte", "startswith", "contains", "exists"]:
                operator = fields.pop()
            
            item = getattr(frame, fields.pop(0))
            while len(fields):
                item = item.get(fields.pop(0), None)
            
            if operator == "eq":
                return item == value
            elif operator == "gt":
                return item > value
            elif operator == "lt":
                return item < value
            elif operator == "gte":
                return item >= value
            elif operator == "lte":
                return item <= value
            elif operator == "startswith":
                return item.startswith(value)
            elif operator == "contains":
                return value in item
            elif operator == "exists":
                return not item == None
                
        for field, value in kwargs.items():
            subset = [f for f in subset if valuecompare(f, field, value)]
                
        return subset

    def _addToBuffer(self):
        
        if not self.id or not Session().framebuffer:
            return
        
        already_in = Frame.lastobjects(id = self.id)
        
        if len(already_in) and already_in[0] == self:
            return
        
        self._recentframes.append(self)
        if len(self._recentframes) > Session().framebuffer:
            self._recentframes.pop(0)


    @LazyProperty
    def thumbnail(self):
        if self.thumbnail_file is None or self.thumbnail_file.grid_id is None:
            img = self.image
            if Session().thumbnail_height:
                thumb_height = float(Session().thumbnail_height)
            else:
                thumb_height = 140.0
            thumbnail_img = img.scale(thumb_height / float(img.height))
            if self.id and not "is_slave" in Session().mongo:
                img_data = StringIO()
                thumbnail_img.save(img_data, "jpeg", quality = 75)
                self.thumbnail_file.put(img_data.getvalue(), content_type='image/jpeg')
                self.save(publish=False)
        else:
            self.thumbnail_file.get().seek(0,0)
            thumbnail_img = Image(pil.open(StringIO(self.thumbnail_file.read())))
        return thumbnail_img

    @LazyProperty
    def clip(self):
        return Clip.objects.get(id=self.clip_id)

    @property
    def image(self):
        if self._imgcache != '':
            return self._imgcache
        if self.clip_id is not None:
            return self.clip.images[self.clip_frame]

        self.imgfile.get().seek(0,0) #hackity hack, make sure the FP is at 0
        if self.imgfile and self.imgfile.grid_id != None:
            try:
                self._imgcache = Image(pil.open(StringIO(self.imgfile.read())))
            except (IOError, TypeError): # pragma no cover
                self._imgcache = None
        else: # pragma no cover
            self._imgcache = None

        return self._imgcache

    @image.setter
    def image(self, value):
        self._imgcache_dirty = True
        self.width, self.height = value.size()
        self._imgcache = value

    def save_image(self):
        if self._imgcache != '' and self._imgcache_dirty:
            s = StringIO()
            img = self._imgcache
            if self.clip_id is None:
                img.getPIL().save(s, "jpeg", quality = Session().compression_quality or 100)
                self.imgfile.replace(s.getvalue(), content_type = "image/jpeg")
          
            self._imgcache_dirty = False
            
        return self.imgfile.grid_id

    def delete_image(self):
        self.imgfile.delete()
        self._imgcache = ''
        self._imgcache_dirty = False
        if self.thumbnail_file:
            self.thumbnail_file.delete()

    def has_image_data(self):
        if self.clip_id and self.clip: return True
        if self.imgfile and self.imgfile.grid_id != None: return True
        return False
       
    def __repr__(self): # pragma no cover
        capturetime = '???'
        if self.capturetime:
            capturetime = self.capturetime.ctime()
        return "<SimpleSeer Frame Object %d,%d captured with '%s' at %s>" % (
            self.width, self.height, self.camera, capturetime)
        
    def save(self, *args, **kwargs):
        from .Inspection import Inspection
        from .Measurement import Measurement
        
        #TODO: sometimes we want a frame with no image data, basically at this
        #point we're trusting that if that were the case we won't call .image
        self.save_image()
        
        epoch_ms = timegm(self.capturetime.timetuple()) * 1000 + self.capturetime.microsecond / 1000
        # Mongo will automatically fix the datetime but not the epoch
        if self.capturetime.tzinfo:
            diff = self.capturetime.tzinfo.utcoffset(self.capturetime)
            tzoffset = (-1 * diff.days * 86400) - diff.seconds
            epoch_ms += (tzoffset * 1000)
        if self.capturetime_epoch != epoch_ms:
            self.capturetime_epoch = epoch_ms
        
        for m in Measurement.objects:
            m.tolerance(self, self.results)

        # Aggregate the tolerance states into single measure
        self.metadata['tolstate'] = 'Pass'
        for r in self.results:
            if r.state > 0:
                self.metadata['tolstate'] = 'Fail'
        
        if len(self.results) == 0:
            self.metadata['tolstate'] = 'Warn'

        self.updatetime = datetime.utcnow()
        
        newFrame = False
        if not self.id:
            newFrame = True

        publish = True
        if 'publish' in kwargs:
            publish = kwargs.pop('publish')

        super(Frame, self).save(*args, **kwargs)
        
        if newFrame and Session().framebuffer:
            self._addToBuffer()
        
        
        # Once everything else is saved, publish result
        # Do not place any other save actions after this line or realtime objects will miss data
        # Only publish to frame/ channel if this is a new frame (not a re-saved frame from a backfill)
        
        if publish:
            if newFrame:
                channel = "frame/"
            else:
                channel = "frameupdate/"
            
            #send the frame with limited feature data, and some other stuff
            limitedFeats = []
            for feat in self.features:
                tmpFeat = {}
                tmpFeat['featuredata'] = feat.featuredata
                tmpFeat['inspection'] = str(feat.inspection)
                limitedFeats.append(tmpFeat)
            realtime.ChannelManager().publish(channel, dict(
                id = str(self.id),
                capturetime = self.capturetime,
                capturetime_epoch = self.capturetime_epoch,
                updatetime = timegm(self.updatetime.timetuple()),
                localtz = self.localtz,
                camera = self.camera,
                results = self.results,
                features = limitedFeats,
                height = self.height,
                width = self.width,
                clip_id = str(self.clip_id),
                clip_frame = self.clip_frame,
                imgfile = "/grid/imgfile/" + str(self.id),
                thumbnail_file = "/grid/thumbnail_file/" + str(self.id),
                metadata = self.metadata,
                notes = self.notes)
            )
            
        
    def delete(self, *args, **kwargs):
        if not kwargs.get("publish", True):
            kwargs.pop("publish")
        elif self.id:
            realtime.ChannelManager().publish("framedelete/", { "id": str(self.id) })
        
        self.delete_image()
        super(Frame, self).delete(*args, **kwargs)
        
    def serialize(self):
        s = StringIO()
        try:
            self.image.save(s, "webp", quality = 80)
            return dict(
                content_type='image/webp',
                data=s.getvalue())
        except KeyError:
            self.image.save(s, "jpeg", quality = 80)
            return dict(
                content_type='image/jpeg',
                data=s.getvalue())

    @classmethod
    def search(cls, filters, sorts, skip, limit):
        db = cls._get_db()
        # Use the agg fmwk to generate frame ids
        pipeline = [
            # initial match to reduce number of frames to search
            {'$match': filters },
            # unwind features and results so we can do complex queries
            # against a *single* filter/result
            {'$unwind': '$features'},
            {'$unwind': '$results' },
            # Re-run the queries
            {'$match': filters },
            {'$sort': sorts },
            {'$project': {'_id': 1} }]
        cmd = db.command('aggregate', 'frame', pipeline=pipeline)
        total_frames = len(cmd['result'])
        seen = set()
        ids = []
        # We have to do skip/limit in Python so we can skip over duplicate frames
        for doc in cmd['result']:
            id = doc['_id']
            if id in seen: continue
            seen.add(id)
            if skip > 0:
                skip -= 1
                continue
            ids.append(id)
            if len(ids) >= limit: break
        frames = cls.objects.filter(id__in=ids)
        frame_index = dict(
            (f.id, f) for f in frames)
        chosen_frames = []
        for id in ids:
            frame = frame_index.get(id)
            if frame is None: continue
            chosen_frames.append(frame)
        earliest_date = None
        if 'capturetime' not in filters:
            earliest_frame = cls.objects.filter(**filters).order_by('capturetime').limit(1).first()
            if earliest_frame:
                earliest_date = earliest_frame.capturetime
        return total_frames, chosen_frames, earliest_date

