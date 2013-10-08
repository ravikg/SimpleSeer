import time
from collections import deque
from Queue import Queue, Empty
from cStringIO import StringIO
from worker import Foreman

import gevent
import signal

from .Session import Session

from . import models as M
from . import util
from .base import jsondecode, jsonencode
from .camera import StillCamera, VideoCamera

from realtime import ChannelManager
from celery.exceptions import TimeoutError

import logging
log = logging.getLogger(__name__)

class Core(object):
    '''Implements the core functionality of SimpleSeer
       - capture
       - inspect
       - measure
       - watch
    '''
    _instance=None
    _queue = {} # Processing queue if frames are scheduled

    class Transition(Exception):
        def __init__(self, state):
            self.state = state

    def __init__(self, config):
        if Core._instance is not None:
            assert RuntimeError, 'Only one state machine allowed currently'
        Core._instance = self
        self._states = {}
        self._cur_state = None
        self._events = Queue()
        self._clock = util.Clock(1.0, sleep=gevent.sleep)
        self._config = config
        self._worker_enabled = None
        self._worker_checked = None
        self.config = config #bkcompat for old SeerCore stuff
        self.cameras = []
        self.video_cameras = []
        self.log = logging.getLogger(__name__)
        self._mem_prof_ticker = 0
        self._channel_manager = ChannelManager(shareConnection=False)
        self._subscriptions = []

        for cinfo in config.cameras:
            cam = StillCamera(**cinfo)
            video = cinfo.get('video')
            if video is not None:
                cam = VideoCamera(cam, 1.0, **video)
                cam.start()
                self.video_cameras.append(cam)
            self.cameras.append(cam)

        util.load_plugins()
        self.reloadInspections()

        if self.config.framebuffer:
            log.warn("Framebuffer is active, while worker is enabled.  Workers can not handle framebuffer calls, so you should add skip_worker_check: 1 to the config")

        self.lastframes = deque()
        self.framecount = 0
        self.reset()

    @classmethod
    def get(cls):
        return cls._instance

    def reloadInspections(self):
        i = list(M.Inspection.objects)
        m = list(M.Measurement.objects)
        w = list(M.Watcher.objects)
        self.inspections = i
        self.measurements = m
        self.watchers = w

    def subscribe(self, name):
        # Create thread that listens for event specified by name
        # If message received, trigger that event

        def callback(msg):
            data = jsondecode(msg.body)
            self.trigger(name, data)

        def listener():
            self._channel_manager.subscribe(name, callback)

        gevent.spawn_link_exception(listener)

    def publish(self, name, data):
        self._channel_manager.publish(name, data)

    def get_image(self, width, index, camera):
        frame = self.lastframes[index][camera]
        image = frame.image

        if (width):
            image = image.scale(width / float(image.width))

        s = StringIO()
        image.save(s, "jpeg", quality=60)

        return dict(
                content_type='image/jpeg',
                data=s.getvalue())

    def get_config(self):
        return self._config.get_config()

    def reset(self):
        start = State(self, 'start')
        self._states = dict(start=start)
        self._cur_state = start

    def capture(self, indexes = []):
        currentframes = []
        self.framecount += 1

        cameras = self.cameras
        if len(indexes):
            cameras = [ self.cameras[i] for i in indexes ]

        currentframes = [ cam.getFrame() for cam in cameras ]

        while len(self.lastframes) >= (self._config.max_frames or 30):
            self.lastframes.popleft()

        self.lastframes.append(currentframes)
        new_frame_ids = []
        for frame in currentframes:
            new_frame_ids.append(frame.id)

        return currentframes

    def schedule(self, frame, inspections=None, workers=True):
        # Create a queue that hold the inspection iterator for this frame (which will start the inspection if worker running)
        fm = Foreman()
        if fm.workerRunning() == False or Session().disable_workers == True:
            fm._useWorkers = False
        self._queue[frame.id] = {}
        self._queue[frame.id]['features'] = fm.process_inspections(frame, inspections)

    def process(self, frame, inspections=None, measurements=None, overwrite=True, clean=False):
        # WARNING: Workers cannot process the frame if it has not
        # been saved to the database yet. We will automatically
        # save the frame if workers are enabled.
        if not frame.id and Foreman().workerRunning():
            frame.save()

        # First do all features, then do all results            
        if not frame.id in self._queue:
            self.schedule(frame, inspections)
        try:
            features = [ feat for feat in self._queue[frame.id].pop('features') ]
        except TimeoutError:
            log.warn("Worker timed out!  All further inspections will be ran in line.")
            self._worker_enabled = False
            self.schedule(frame, inspections, False)
            # Note: even though we're not using workers anymore, a TimeoutError exception can still be thrown, and will bubble up.
            features = [ feat for feat in self._queue[frame.id].pop('features') ]

        if clean:
            frame.features = []

        if overwrite:
            # Find a list of inspection id from new inspection
            # Use those to find list of features from old frame that are not in list of new
            # Then append those features to the list of new features
            if features:
                newInspections = { feature.inspection: 1 for feature in features }.keys()
            else:
                newInspections = []
            keptFeatures = [ feature for feature in frame.features if not feature.inspection in newInspections ]
            features += keptFeatures

            frame.features = []

        frame.features += features

        # Now that we know we have features, can process measurements
        if not 'results' in self._queue[frame.id]:
            fm = Foreman()
            self._queue[frame.id]['results'] = fm.process_measurements(frame, measurements)

        results = [ res for res in self._queue[frame.id].pop('results') ]

        if clean:
            frame.results = []

        if overwrite:
            if results:
                newResults = { result.measurement_name: 1 for result in results }.keys()
            else:
                newResults = []
            keptResults = [ result for result in frame.results if not result.measurement_name in newResults ]
            results += keptResults

            frame.results = []

        frame.results += results
        self._queue.pop(frame.id)

    @property
    def results(self):
        ret = []
        for frameset in self.lastframes:
            results = []
            for f in frameset:
                results += [f.results for f in frameset]

            ret.append(results)

        return ret

    """
    def get_inspection(self, name):
        return M.Inspection.objects(name=name).next()

    def get_measurement(self, name):
        return M.Measurement.objects(name=name).next()
    """

    def state(self, name):
        if name in self._states: return self._states[name]
        s = self._states[name] = State(self, name)
        return s

    def trigger(self, name, data=None):
        self._events.put((name, data))

    def step(self):
        next = self._cur_state = self._cur_state.run()
        return next

    def wait(self, name):
        while True:
            try:
                (n,d) = self._events.get(timeout=0.5)
                if n == name: return (n,d)
            except Empty:
                continue
            self._cur_state.trigger(n,d)

    def on(self, state_name, event_name):
        state = self.state(state_name)
        if event_name not in self._subscriptions:
            self.subscribe(event_name)
            self._subscriptions.append(event_name)
        return state.on(event_name)

    def run(self, audit=False):
        audit_trail = []
        while True:
            print self._cur_state
            if self._cur_state is None: break
            if audit: audit_trail.append(self._cur_state.name)
            try:
                self._cur_state = self._cur_state.run()
            except self.Transition, t:
                if isinstance(t.state, State):
                    self._cur_state = t.state
                elif t.state is None:
                    self._cur_state = None
                else:
                    self._cur_state = self.state(t.state)
            except Exception, e:
                estate = self._states.get('error',None)
                if estate:
                    log.error("{} error raised in {}".format(e.__class__.__name__, self._cur_state.name))
                    _next = estate.run()
                    audit_trail.append(estate)
                    if _next:
                        self._cur_state = _next
                else:
                    log.warn("No state.error defined")
                    raise e

                audit_trail.append(None)
                return audit_trail

    def set_rate(self, rate_in_hz):
        self._clock = util.Clock(rate_in_hz, sleep=gevent.sleep)
        for cam in self.video_cameras:
            cam.set_rate(rate_in_hz)

    def tick(self):
        #~ from guppy import hpy
        self._handle_events()
        self._clock.tick()

        if self.config.memprofile:
            self._mem_prof_ticker += 1
            if self._mem_prof_ticker == int(self.config.memprofile):
                self._mem_prof_ticker = 0
                #~ self.log.info(hpy().heap())

    def _handle_events(self):
        while True:
            try:
                (n,d) = self._events.get_nowait()
            except Empty:
                break
            self._cur_state.trigger(n,d)

class Event(object):

    def __init__(self, states, state, channel, message):
        self.states = states
        self.state = state
        self.channel = channel
        self.message = message

class State(object):

    def __init__(self, core, name):
        self.core = core
        self.name = name
        self._events = {}
        self._run = None

    def __repr__(self):
        return '<State %s>' % self.name

    def on(self, name):
        def wrapper(callback):
            self._events[name] = callback
            return callback
        return wrapper

    def trigger(self, name, data):
        callback = self._events.get(name)
        if callback is None: return self
        return callback(self, name, data)

    def run(self):
        if self._run:
            return self._run(self)
        return self

    def transition(self, next):
        raise self.core.Transition(next)

    def __call__(self, func):
        self._run = func
        return func
