import bson
import mongoengine

from .base import SimpleDoc, WithPlugins
from .Result import ResultEmbed

from formencode import validators as fev
from formencode import schema as fes
import formencode as fe

from SimpleSeer import validators as V

import logging
log = logging.getLogger()


class MeasurementSchema(fes.Schema):
    name = fev.UnicodeString(not_empty=True) #TODO, validate on unique name
    label = fev.UnicodeString(if_missing=None)
    labelKey = fev.UnicodeString(if_missing=None)
    method = fev.UnicodeString(not_empty=True)
    parameters = V.JSON(if_empty=dict, if_missing=None)
    units = fev.UnicodeString(if_missing="px")
    fixdig = fev.UnicodeString(if_missing=2)
    inspection = V.ObjectId(not_empty=True)
    featurecriteria = V.JSON(if_empty=dict, if_missing=None)
    tolerances = fev.Set(if_empty=[])


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
    #VALIDATION NEEDED: this should be a unique name
    label = mongoengine.StringField()
    labelKey = mongoengine.StringField()
    method = mongoengine.StringField()
    parameters = mongoengine.DictField()
    units = mongoengine.StringField()
    fixdig = mongoengine.IntField()
    inspection = mongoengine.ObjectIdField()
    featurecriteria = mongoengine.DictField()
    tolerances = mongoengine.ListField()

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
        
        results = self.toResults(frame, values)
        results = self.tolerance(frame, results)
        
        return results
        
    def tolerance(self, frame, results):
        
        for result in results:
            if result.measurement_name == self.name:
                testField = None
                if result.numeric:
                    testField = result.numeric
                else:
                    testField = result.string
                
                result.state = 0
                messages = []
                for rule in self.tolerances:
                    if rule['criteria'].keys()[0] in frame.metadata and frame.metadata[rule['criteria'].keys()[0]] == rule['criteria'].values()[0]:
                        criteriaFunc = "testField %s %s" % (rule['rule']['operator'], rule['rule']['value'])
                        match = eval(criteriaFunc, {}, {'testField': testField})
                        
                        if not match:
                            result.state = 1
                            messages.append("%s %s %s" % (self.label, rule['rule']['operator'], rule['rule']['value']))
                        
                result.message = ",".join(messages)
                
        return results
    
    def backfillTolerances(self):
        from .Frame import Frame
        
        for frame in Frame.objects:
            log.info('Backfilling measurement on frame %s' % frame.id)
            if frame.results:
                self.tolerance(frame, frame.results)
                frame.save()
    
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
                inspection_id=self.inspection,
                inspection_name=inspection.name,
                measurement_id=self.id,
                measurement_name=self.name)
            for v in values ]
        frame.results.extend(results)
        return results
    
    def save(self, *args, **kwargs):
        from ..realtime import ChannelManager
        
        if '_changed_fields' not in dir(self) or 'tolerances' in self._changed_fields:
            self.backfillTolerances()
        
        super(Measurement, self).save(*args, **kwargs)
        ChannelManager().publish('meta/', self)

    def __repr__(self):
        return "<Measurement: " + str(self.inspection) + " " + self.method + " " + str(self.featurecriteria) + ">"
            
