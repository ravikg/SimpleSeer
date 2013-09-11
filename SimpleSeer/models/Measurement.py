import bson
import mongoengine
from mongoengine import signals as sig

from .base import SimpleDoc, WithPlugins
from .Result import ResultEmbed

from formencode import validators as fev
from formencode import schema as fes
import formencode as fe

from datetime import datetime

from SimpleSeer import validators as V
from Tolerance import Tolerance
import logging
log = logging.getLogger()


class ResultValidator(fev.FancyValidator):
    def _to_python(self, value, state):
        if value is None: return None
        if isinstance(value, dict) or isinstance(value, list):
            if len(value):
                results = []
                for r in value:
                    if r == ResultEmbed:
                        results.append(r)
                    elif type(r) == dict:
                        re = ResultEmbed()
                        re._data = {}
                        re._data.update(r)
                        results.append(re)
            return results
        raise fev.Invalid('invalid Result object', value, state)

    def _from_python(self, value, state):
        if value is None: return None
        if isinstance(value, dict):
            return value
        raise fev.Invalid('invalid Python dict', value, state)


class MeasurementSchema(fes.Schema):
    id = V.ObjectId(if_empty=None, if_missing=None)
    name = fev.UnicodeString(not_empty=True) #TODO, validate on unique name
    label = fev.UnicodeString(if_missing=None)
    labelkey = fev.UnicodeString(if_missing=None)
    method = fev.UnicodeString(not_empty=True)
    parameters = V.JSON(if_empty=None, if_missing=None)
    units = fev.UnicodeString(if_missing="px")
    fixdig = fev.UnicodeString(if_missing=2)
    inspection = V.ObjectId(not_empty=True)
    featurecriteria = V.JSON(if_empty=None, if_missing=None)
    tolerances = fev.Set(if_empty=[])
    tolerance_list = V.ReferenceFieldList(ref_type=Tolerance)
    updatetime = fev.UnicodeString()
    conditions = fev.Set(if_empty=[])
    booleans = fev.Set(if_empty=[])
    executeorder = fev.Int(if_empty=None, if_missing=None)


class Measurement(SimpleDoc, WithPlugins, mongoengine.Document):
    """
        The measurement object takes any regions of interest in an Inspection and
        returns a Result object with the appropriate measurement.

        The handler

        Note that measurements are each linked to a single Inspection object.

        Measurement(name =  "blob_largest_area",
            label = "Blob Area",
            method = "area",
            parameters = dict(),
            featurecriteria = dict( index = -1 ),
            units =  "px",
            inspection = insp.id)


    """
    name = mongoengine.StringField(default='')
    label = mongoengine.StringField(default='')
    labelkey = mongoengine.StringField(default='')
    method = mongoengine.StringField(default='')
    # use (int) parameters['interval'] to run Measurement every N seconds
    parameters = mongoengine.DictField(default={})
    units = mongoengine.StringField(default='px')
    fixdig = mongoengine.IntField(default=99)
    inspection = mongoengine.ObjectIdField(default=None)
    featurecriteria = mongoengine.DictField(default={})
    tolerances = mongoengine.ListField(default=[])
    tolerance_list = mongoengine.ListField(mongoengine.ReferenceField('Tolerance', dbref=False, reverse_delete_rule=mongoengine.NULLIFY))
    updatetime = mongoengine.DateTimeField(default=None)
    conditions = mongoengine.ListField(default=[])
    booleans = mongoengine.ListField(default=[])
    executeorder = mongoengine.IntField(default=0)

    meta = {
        'ordering': ['executeorder']
    }

    def execute(self, frame, features=None):
        
        if not features:
            features = frame.features
        
        featureset = self.findFeatureset(features)
        #this will catch nested features

        if self.featurecriteria.has_key("index"):
            i = int(self.featurecriteria['index'])

            if len(featureset) > i:
                featureset = [featureset[i]]
            else:
                return []
        #TODO more advanced filtering options here

        values = []
        hasToleranceFunction = False
        if len(featureset) and hasattr(featureset[0], self.method):
            values = [getattr(f, self.method) for f in featureset]
        elif len(featureset) and featureset[0].featuredata.has_key(self.method):
            values = [f.featuredata[self.method] for f in featureset]
        else:
            function_ref = ""
            try:
                function_ref = self.get_plugin(self.method)
            except ValueError:
                return []

            values = function_ref(frame, featureset)
            hasToleranceFunction = hasattr(function_ref, 'tolerance')

        if self.booleans:
            values = self.testBooleans(values, self.booleans, values)

        if self.conditions:
            conds = self.testBooleans(values, self.conditions, values)
            values = [ v for v, c in zip(values, conds) if c ]

        results = self.toResults(frame, values)

        if hasToleranceFunction:
            results = function_ref.tolerance(frame, results)
        else:
            results = self.tolerance(frame, results)

        return results

    def measurementToValue(self, results, meas_id, idx):
        # Find the result matching the measurement expression
        # The try to match the indexes of the results.  E.g., if this is the height measure of the 3rd feature, look for the width measure of the 3rd feature
        for r in results:
            if r.measurement_id == meas_id and r.featureindex == idx:
                if r.numeric:
                    return r.numeric
                else:
                    return r.string

    def testBooleans(self, values, conds, results):
        # Returns 0/1 for passing/failing conditions
        cond_values = []
        for cond in conds:
            for i, val in enumerate(values):
                testValue = cond['value']
                if type(testValue) == bson.ObjectId:
                    testValue = self.measurementToValue(results, testValue, i)
                if type(testValue) == mongoengine.base.BaseDict:
                    testValue = self.parseMex(testValue, i, results)
                criteriaFunc = "testField %s %s" % (cond['op'], testValue)
                match = eval(criteriaFunc, {}, {'testField': val})
                cond_values.append(int(match))

        return cond_values

    def parseMex(self, mex, i, results):
        left = mex['field']
        if type(left) == bson.ObjectId:
            left = self.measurementToValue(results, left, i)
        right = mex['value']
        if type(right) == bson.ObjectId:
            right = self.measurementToValue(results, right, i)

        return eval('%s %s %s' % (left, mex['op'], right), {}, {})


    def tolerance(self, frame, results):

        try:
            function_ref = self.get_plugin(self.method)
            hasToleranceFunction = hasattr(function_ref, 'tolerance')
            if hasToleranceFunction:
                return function_ref.tolerance(frame, results)
        except:
            pass                

        for result in results:
            if result.measurement_name == self.name:
                testField = None
                if result.numeric is not None:
                    testField = result.numeric
                else:
                    testField = result.string

                result.state = 0
                messages = []
                for rule in self.tolerance_list:
                    if rule['criteria'].values()[0] == 'all' or (rule['criteria'].keys()[0] in frame.metadata and frame.metadata[rule['criteria'].keys()[0]] == rule['criteria'].values()[0]):
                        criteriaFunc = "testField %s %s" % (rule['rule']['operator'], rule['rule']['value'])
                        match = eval(criteriaFunc, {}, {'testField': testField})

                        if not match:
                            result.state = 1
                            if 'msg' in rule:
                                messages.append(rule['msg'])
                            elif 'msgfeat' in rule:
                                field = rule['msgfeat']
                                sub = ''
                                if '.' in field:
                                    parts = field.split('.')
                                    field = parts[0]
                                    sub = parts[1]

                                for feat in frame.features:
                                    if field in dir(feat):
                                        featMsg = feat[field]
                                    elif field in feat['featuredata'].keys():
                                        if sub:
                                            featMsg = feat['featuredata'][field].get(sub, '')
                                        else:
                                            featMsg = feat['featuredata'].get(field, '')
                                    if featMsg:
                                        messages.append(featMsg)
                            else:
                                messages.append("%s %s %s" % (self.label, rule['rule']['operator'], rule['rule']['value']))

                result.message = ",".join(messages)

        return results

    def backfillTolerances(self):
        from .Frame import Frame
        from .Alert import Alert
        from ..realtime import ChannelManager
        
        #NJO, we shouldn't be doing this, but we need something to trigger
        #and our REST stuff is a little too static
        Alert.info("Backfilling Measurements")

        for frame in Frame.objects:
            log.info('Backfilling measurement on frame %s' % frame.id)
            if frame.results:
                self.tolerance(frame, frame.results)
                frame.save(publish=False)
        Alert.clear()
        Alert.refresh('backfill')

    def findFeatureset(self, features):

        fs = []
        for f in features:
            if f.inspection == self.inspection:
                fs.append(f)

            if len(f.children):
                fs = fs + self.findFeatureset(f.children)

        return fs

    def toResults(self, frame, values):
        from .Inspection import Inspection
        if not values or not len(values):
            return []

        def numeric(val):
            try:
                return float(val)
            except:
                try:
                    return float(val[0] + val[1] + val[2]) / 3
                except:
                    return None

        inspection = Inspection.objects.get(id=self.inspection)
        results = [
            ResultEmbed(
                result_id=bson.ObjectId(),
                numeric=numeric(v),
                string=str(v),
                featureindex=i,
                inspection_id=self.inspection,
                inspection_name=inspection.name,
                measurement_id=self.id,
                measurement_name=self.name)
            for i, v in enumerate(values) ]
        return results

    def save(self, *args, **kwargs):
        from ..realtime import ChannelManager
        from ..Session import Session
        tolChange = '_changed_fields' in self and 'tolerance_list' in self._changed_fields

        # Optional parameter: skipDeps
        try:
            skipDeps = kwargs.pop('skipDeps')
        except:
            skipDeps = 0

        if not skipDeps:
            if '_changed_fields' not in dir(self) or 'executeorder' in self._changed_fields:
                self.updateDependencies()

        self.updatetime = datetime.utcnow()

        # Ensure name is unique
        for m in Measurement.objects:
            if m.name == self.name and m.id != self.id:
                log.info('trying to save measurements with duplicate names: %s' % m.name)
                self.name = self.name + '_1'

        super(Measurement, self).save(*args, **kwargs)
        ChannelManager().publish('meta/', self)
        
        if not Session().procname == 'meta':
            if tolChange:
                log.info('Sending backfill request to OLAP')
                ChannelManager().rpcSendRequest('backfill/', {'type': 'tolerance', 'id': self.id})
            
    def measurementsBefore(self):
        # Find the list of measurements that need to execute before this one
        before = []
        for cond in self.conditions:
            if type(cond['value']) == bson.ObjectId:
                before.append(cond['value'])

        return before

    def measurementsAfter(self):
        # Find the list of measurements that need to execute after this one
        after = []
        for m in Measurement.objects:
            before = m.measurementsBefore()
            if self.id in before:
                after.append(m)

        return after

    def updateDependencies(self, visited=[]):
        # Recursively update the dependency tree to update execution order and check for cycles

        # Add myself to the list of nodes visited
        visited.append(self.id)

        # Update execution order
        xorder = 0
        before = self.measurementsBefore()
        for b in before:
            m = Measurement.objects.get(id=b)
            xorder = max(xorder, m.executeorder + 1)

        # Only need to progress if the execution order changed
        if xorder != self.executeorder:
            # Update execution order of self
            self.executeorder = xorder
            # We are already computing dependencies, so don't re-run when saving
            self.save(skipDeps=True)

            # Change the execution order of measurement that depend on self
            after = self.measurementsAfter()
            for a in after:
                if a.id in visited:
                    raise MeasurementError('Invalid dependency.  Circular reference: %s' % a.name)
                else:
                    m = Measurement.objects.get(id=a)
                    m.updateDependencies(visited)

    def findCharts(self):
        # Get the list of charts that show data from this measurement
        from SeerCloud.models.OLAP import OLAP
        from SeerCloud.models.Chart import Chart

        olaps = OLAP.objects(olapFilter__type=self.name)
        charts = []

        for o in olaps:
            charts += Chart.objects(olap=o.name)

        return charts


    def __init__(self, **kwargs):
        from .base import checkPreSignal, checkPostSignal
        from SimpleSeer.Session import Session
        
        super(Measurement, self).__init__(**kwargs)
        
        app = Session._Session__shared_state['appname']
        
        for pre in Session().get_triggers(app, 'Measurement', 'pre'):
            sig.pre_save.connect(pre, sender=Frame, weak=False)
        
        for post in Session().get_triggers(app, 'Measurement', 'post'):
            sig.post_save.connect(post, sender=Frame, weak=False)

    def __repr__(self):
        return "<Measurement: " + str(self.inspection) + " " + self.method + " " + str(self.featurecriteria) + ">"

    def __eq__(self, other):
        if isinstance(other, self.__class__):
            # Note: ignoring name to test if this measurement is functionally equivalent to other inspection (name is irrelevant)
            banlist = [None, 'updatetime', 'name']
            params = [ a for a in self.__dict__['_data'] if not a in banlist ]

            for p in params:
                if self.__getattribute__(p) != other.__getattribute__(p):
                    return False
            return True
        else:
            return False



class MeasurementError(Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)
