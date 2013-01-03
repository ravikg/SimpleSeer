from cStringIO import StringIO
from calendar import timegm
import mongoengine

from SimpleSeer.base import Image, pil, pygame
from SimpleSeer import util
from SimpleSeer.Session import Session

from formencode import validators as fev
from formencode import schema as fes
from SimpleSeer import validators as V
import formencode as fe

from datetime import datetime

from .base import SimpleDoc, SONScrub
from .FrameFeature import FrameFeature
from .Clip import Clip
from .Result import Result, ResultEmbed
from .. import realtime
from ..util import LazyProperty


class FrameSchema(fes.Schema):
    allow_extra_fields=True
    filter_extra_fields=True
    camera = fev.UnicodeString(not_empty=True)
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
    camera = mongoengine.StringField()
    features = mongoengine.ListField(mongoengine.EmbeddedDocumentField(FrameFeature))
    results = mongoengine.ListField(mongoengine.EmbeddedDocumentField(ResultEmbed))
    
    height = mongoengine.IntField(default = 0)
    width = mongoengine.IntField(default = 0)
    clip_id = mongoengine.ObjectIdField(default=None)
    clip_frame = mongoengine.IntField(default=None)
    imgfile = mongoengine.FileField()
    layerfile = mongoengine.FileField()
    thumbnail_file = mongoengine.FileField()
    metadata = mongoengine.DictField()
    notes = mongoengine.StringField()
    _imgcache = ''
    _imgcache_dirty = False
    

    meta = {
        'indexes': ["capturetime", "-capturetime", ('camera', '-capturetime'), "-capturetime_epoch", "capturetime_epoch", "results", "results.state", "metadata"]
    }
    
    @classmethod
    #which fields we care about for Filter.py
    def filterFieldNames(cls):
        return ['_id', 'camera', 'capturetime', 'capturetime_epoch', 'metadata', 'notes', 'height', 'width', 'imgfile', 'results']


    @LazyProperty
    def thumbnail(self):
        if self.thumbnail_file is None or self.thumbnail_file.grid_id is None:
            img = self.image
            thumbnail_img = img.scale(140.0 / img.height)
            if self.id and not "is_slave" in Session().mongo:
                img_data = StringIO()
                thumbnail_img.save(img_data, "jpeg", quality = 75)
                self.thumbnail_file.put(img_data.getvalue(), content_type='image/jpeg')
                self.save()
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


        if self.layerfile:
            self.layerfile.get().seek(0,0)
            self._imgcache.dl()._mSurface = pygame.image.fromstring(self.layerfile.read(), self._imgcache.size(), "RGBA")

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
                img.getPIL().save(s, "jpeg", quality = 100)
                self.imgfile.replace(s.getvalue(), content_type = "image/jpg")
          
            if len(img._mLayers):
                if len(img._mLayers) > 1:
                    mergedlayer = DrawingLayer(img.size())
                    for layer in img._mLayers[::-1]:
                        layer.renderToOtherLayer(mergedlayer)
                else:
                    mergedlayer = img.dl()
                self.layerfile.replace(pygame.image.tostring(mergedlayer._mSurface, "RGBA"))
                #TODO, make layerfile a compressed object
            #self._imgcache = ''
            self._imgcache_dirty = False
            
        return self.imgfile.grid_id

    def delete_image(self):
        self.imgfile.delete()
        self._imgcache = ''
        self._imgcache_dirty = False

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
        #TODO: sometimes we want a frame with no image data, basically at this
        #point we're trusting that if that were the case we won't call .image

        self.save_image()
        
        epoch_ms = timegm(self.capturetime.timetuple()) * 1000 + self.capturetime.microsecond / 1000
        if self.capturetime_epoch != epoch_ms:
            self.capturetime_epoch = epoch_ms
        
        # Aggregate the tolerance states into single measure
        self.metadata['tolstate'] = 'Pass'
        for r in self.results:
            if r.state > 0:
                self.metadata['tolstate'] = 'Fail'
        
        self.updatetime = datetime.utcnow()
        
        newFrame = False
        if not self.id:
            newFrame = True
        
        super(Frame, self).save(*args, **kwargs)

        #TODO, this is sloppy -- we should handle this with cascading saves
        #or some other mechanism
        #for r in self.results:
        #    result, created = r.get_or_create_result()
        #    result.capturetime = self.capturetime
        #    result.frame_id = self.id
        #    result.save(*args, **kwargs)
        
        # Once everything else is saved, publish result
        # Do not place any other save actions after this line or realtime objects will miss data
        # Only publish to frame/ channel if this is a new frame (not a re-saved frame from a backfill)
        if newFrame:
            realtime.ChannelManager().publish('frame/', self)
        
        
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
