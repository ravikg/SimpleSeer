import pkg_resources
import sys

from User import User, UserSchema
from Frame import Frame, FrameSchema
from FrameFeature import FrameFeature
from Inspection import Inspection, InspectionSchema
from Measurement import Measurement, MeasurementSchema
from FrameSet import FrameSet, FrameSetSchema
from Result import ResultEmbed
from Watcher import Watcher
from Alert import Alert
from Clip import Clip
from Context import Context, ContextSchema

for ep in pkg_resources.iter_entry_points('seercloud.models'):
    mod = sys.modules['SimpleSeer.models.%s' % ep.name] = __import__(ep.module_name, globals(), locals(), [ep.name])
    vars()[ep.name] = mod.__getattribute__(ep.name)

    mod = sys.modules['SimpleSeer.models.%sSchema' % ep.name] = __import__(ep.module_name, globals(), locals(), [ep.name + 'Schema'])
    vars()[ep.name + 'Schema'] = mod.__getattribute__(ep.name + 'Schema')

models = ("User", "Frame", "FrameFeature", "Inspection", "Measurement", "Result", "Watcher", "Clip")


