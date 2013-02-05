import bson
import mongoengine

from .base import SimpleDoc, WithPlugins
from .Result import ResultEmbed

from formencode import validators as fev
from formencode import schema as fes
import formencode as fe

from datetime import datetime

from SimpleSeer import validators as V

import logging
log = logging.getLogger()


class MeasurementSchema(fes.Schema):
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
    updatetime = fev.UnicodeString()


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
    name = mongoengine.StringField()
    label = mongoengine.StringField()
    labelkey = mongoengine.StringField()
    method = mongoengine.StringField()
    parameters = mongoengine.DictField()
    units = mongoengine.StringField()
    fixdig = mongoengine.IntField(default=99)
    inspection = mongoengine.ObjectIdField()
    featurecriteria = mongoengine.DictField()
    tolerances = mongoengine.ListField()
    updatetime = mongoengine.DateTimeField()
    conditions = mongoengine.ListField()
    booleans = mongoengine.ListField()
    executeorder = mongoengine.IntField(default=0)
    
    meta = {
        'ordering': ['executeorder']
    }

    def execute(self, frame, features):
        featureset = self.findFeatureset(features)
        #this will catch nested features

        if not len(featureset):
            return []
         
        if self.featurecriteria.has_key("index"):
            i = int(self.featurecriteria['index'])
            
            if len(featureset) > i:
                featureset = [featureset[i]]
            else:
                return []
        #TODO more advanced filtering options here

        values = []
        if hasattr(featureset[0], self.method):
            values = [getattr(f, self.method) for f in featureset] 
        elif featureset[0].featuredata.has_key(self.method):
            values = [f.featuredata[self.method] for f in featureset]
        else:        
            function_ref = ""
            try:
                function_ref = self.get_plugin(self.method)
            except ValueError:
                print "Can't fetch measurement plugin " + self.method
                return []
            
            values = function_ref(frame, featureset)
        
        if self.booleans:
            values = self.testBooleans(values, self.booleans, frame.results)
        
        if self.conditions:
            conds = self.testBooleans(values, self.conditions, frame.results)
            values = [ v for v, c in zip(values, conds) if c ]
        
        results = self.toResults(frame, values)
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
        
        for result in results:
            if result.measurement_name == self.name:
                testField = None
                if result.numeric is not None:
                    testField = result.numeric
                else:
                    testField = result.string
                
                result.state = 0
                messages = []
                for rule in self.tolerances:
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
        
        #NJO, we shouldn't be doing this, but we need something to trigger
        #and our REST stuff is a little too static
        Alert.info("Backfilling Measurements")
        
        for frame in Frame.objects:
            log.info('Backfilling measurement on frame %s' % frame.id)
            if frame.results:
                self.tolerance(frame, frame.results)
                frame.save()
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
        frame.results.extend(results)
        return results
    
    def save(self, *args, **kwargs):
        from ..realtime import ChannelManager
        
        # Optional parameter: skipBackfill
        try:
            skipBackfill = kwargs.pop('skipBackfill')
        except:
            skipBackfill = 0
        
        if not skipBackfill: 
            if '_changed_fields' not in dir(self) or 'tolerances' in self._changed_fields:
                self.backfillTolerances()
        
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
