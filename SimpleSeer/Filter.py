import logging

from .models.Frame import Frame
from .models.Inspection import Inspection
from .models.Measurement import Measurement
from datetime import datetime
from calendar import timegm

import numpy as np

log = logging.getLogger(__name__)

class Filter():
    
    names = {}
    
    def getFrames(self, allFilters, skip=0, limit=float("inf"), sortinfo = {}, timeEpoch = True):
        
        pipeline = []
        frames = []
        measurements = []
        features = []
        
        # Filter the data based on the filter parameters
        # Frame features are easy to filter, but measurements and features are embedded in the frame
        # so they need their own syntax to filter
        for f in allFilters:
            if f['type'] == 'measurement':
                measurements.append(f)
            elif f['type'] == 'frame':
                frames.append(f)
            elif f['type'] == 'framefeature':
                features.append(f)
        
        # Need to initially construct/modify a few fields for future filters
        pipeline += self.initialFields(projResult = (len(measurements) > 0), projFeat = (len(features) > 0))
        
        if frames:
            pipeline += self.filterFrames(frames)
        
        if measurements:    
            pipeline += self.conditional(measurements, 'results', 'measurement_name')           
        
        if features:
            pipeline += self.conditional(measurements, 'features', 'featuretype')     
        
        # Sort the results
        pipeline += self.sort(sortinfo)
        
        #pipeline.append({'$match': {'capturetime_epoch': 0}})
        #for p in pipeline:
        #    print '%s' % str(p)
        
        # This is all done through mongo aggregation framework
        db = Frame._get_db()
        cmd = db.command('aggregate', 'frame', pipeline = pipeline)
        results = cmd['result']
        
        # Perform the skip/limit 
        # Note doing this in python instead of mongo since need original query to give total count of relevant results
        if skip < 0:
            if abs(skip) - 1 > len(results):
                results = results[skip:skip+limit]
        elif skip < len(results):
            if (skip + limit) > len(results):
                results = results[skip:]
            else:
                results = results[skip:skip+limit]
        else:
            return 0, []
                
        return len(cmd['result']), results    
    
    def negativeFilter(self, originalFilter = []):
        # used to convert filter commands that assume provide all fields except those banned
        # to a filter that returns only those fields specified
        # which is the format assumed by filters here
        
        newFilters = []
        featureNames, resultNames = self.keyNamesHash()
        
        for insp in featureNames.keys():
            for field in featureNames[insp]:
                for orig in originalFilter:
                    filtname = '%s.%s' % (insp, field)
                    if orig['type'] == 'framefeature' and orig['name'] == filtname:
                        newFilters.append(orig)
                    else:
                        newFilters.append({'type':'framefeature', 'exists': True, 'name': filtname})
        
        for meas in resultNames.keys():
            for field in resultNames[meas]:
                for orig in originalFilter:
                    filtname = '%s.%s' % (meas, field)
                    if orig['type'] == 'measurement' and orig['name'] == filtname:
                        newFilters.append(orig)
                    else:
                        newFilters.append({'type':'measurement', 'exists': True, 'name':filtname})
        
        return newFilters
        
    def initialFields(self, projResult = False, projFeat = False):
        # This is a pre-filter of the relevant fields
        # It constructs a set of fields helpful when grouping by time
        # IT also constructs a set of custom renamed fields for use by other filters
        
        fields = {}
        
        # First select the fields from the frame to include
        for p in Frame.filterFieldNames():
            
            fields[p] = 1
        
        # And we always need the features and results
        
        if projFeat:
            p, g = self.rewindFields('features')
            fields.update(p)
            del fields['features']
        if projResult:
            p, g = self.rewindFields('results')
            fields.update(p)
            del fields['results']
            
        # Always want the 'id' field, which sometimes comes through as _id
        fields['id'] = '$_id'
        return [{'$project': fields}]
    
    
    def filterFrames(self, frameQuery):
        # Construct the filter based on fields in the Frame object
        # Note that all timestamps are passed in as epoch milliseconds, but
        # fromtimestamp() assumes they are in seconds.  Hence / 1000
 
        filters = {}
        for f in frameQuery:    
            if 'eq' in f:
                if (type(f['eq']) == str or type(f['eq']) == unicode) and f['eq'].isdigit():
                    f['eq'] = float(f['eq'])
                    
                if f['name'] == 'capturetime':
                    f['eq'] = datetime.fromtimestamp(f['eq'] / 1000)
                comp = f['eq']
                
            else:
                comp = {}
                if 'gt' in f and f['gt']:
                    if f['name'] == 'capturetime':
                        f['gt'] = datetime.fromtimestamp(f['gt'] / 1000)
                    comp['$gt'] = f['gt']
                if 'lt' in f and f['lt']:
                    if f['name'] == 'capturetime':
                        f['lt'] = datetime.fromtimestamp(f['lt'] / 1000)
                    comp['$lt'] = f['lt']
            if 'exists' in f:
                comp = {'$exists': True}
             
            filters[f['name']] = comp
        
        return [{'$match': filters}]
    
    def sort(self, sortinfo):
        # Sort based on specified parameters
        # Sorting may be done on fields inside the results or features
        
        parts = []
        
        if sortinfo:
            sortinfo['order'] = int(sortinfo['order'])
            if sortinfo['type'] == 'measurement':
                parts.append({'$sort': {'results.numeric': sortinfo['order'], 'results.string': sortinfo['order']}})
            elif sortinfo['type'] == 'framefeature':
                feat, c, field = sortinfo['name'].partition('.')
                parts.append({'$sort': {'features.' + field: sortinfo['order']}})
            else:
                parts.append({'$sort': {sortinfo['name']: sortinfo['order']}})
        else:
            parts.append({'$sort': {'capturetime': 1}})
        
        return parts
    
    def rewindFields(self, field):
        # Handle the grouping when undoing the unwind operations
        # Also filters out unnecessary fields from embedded docs to keep results smaller
        
        proj = {}
        group = {}
        
        # Only keep those keys requested
        featKeys, resKeys = self.keyNamesHash()
        
        if field == 'results':
            useKeys = resKeys
        elif field == 'features':
            useKeys = featKeys
            
        for key in useKeys:
            for f in useKeys[key]:
                proj[field + '.' + f] = 1
        
        for key in Frame.filterFieldNames():
            # Have to rename the id field since $group statements assume existence of _id as the group_by parameter
            if key == 'id':
                key = '_id'
            proj[key] = 1
            
            group[key] = {'$first': '$' + key}
        
        # re-groupt the (results | features)
        group[field] = {'$addToSet': '$' + field}
            
        group['_id'] = '$_id'
        # But a lot of stuff also wants an id instead of _id
        group['id'] = {'$first': '$_id'}

        return proj, group
    
    def conditional(self, filters, embedField, nameField):
        
        allfilts = []
        for f in filters:    
            name, c, field = f['name'].partition('.')
            
            comp = {}
            if 'eq' in f:
                comp[field] = f['eq']
            if 'gt' in f or 'lt' in f:
                parts = {}
                if 'gt' in f:
                    parts['$gte'] = f['gt']
                if 'lt' in f:
                    parts['$lte'] = f['lt']
                comp[field] = parts
            if 'exists' in f:
                comp[field] = {'$exists': True}
                
            comp[nameField] = name
            
            allfilts.append({'$match': {embedField: {'$elemMatch': comp}}})
                
        return allfilts
        
        
    def checkFilter(self, filterType, filterName, filterFormat):
        # Given information about a filter, checks if that field
        # exists in the database.  If so, provides the fitler
        # parameters, such as lower/upper bounds, or lists of options
        
        from datetime import datetime
        from bson import Code
        
        if not filterFormat in ['numeric', 'string', 'autofill', 'datetime']:
            return {"error":"unknown format"}
        if not filterType in ['measurement', 'frame', 'framefeature']:
            return {"error":"unknown type"}
        
        
        if filterType == 'frame':
            
            # Need to convert mongo dotted notation to hash for javascript
            fieldpart = filterName.split('.')
            field = fieldpart[0]
            if len(fieldpart) > 1 and not field == 'results' and not field == 'features':
                field += ('["%s"]' % fieldpart[1])
            elif len(fieldpart) > 1:
                field += ("[i].%s" % fieldpart[1]) 
            
            
            if (filterFormat == 'numeric') or (filterFormat == 'datetime'):
                emit = "  emit(1, {min: val, max: val});"
            else:
                emit = ("  arr = {};" 
                       "  arr[val] = 1;" 
                       "  emit(1, arr);")
        
            loopstart = ""
            loopend = ""
            
            if fieldpart[0] == 'results' or fieldpart[0] == 'features':
                loopend = "}"
                loopstart = "for (i = 0; i < this." + fieldpart[0] + ".length; i++) {"
        
            field = 'this.%s' % field
            mapfn = Code("function () {" + loopstart +
                         "  if (this." + fieldpart[0] + ") {"
                         "    val = " + field + ";" + emit +
                         "  }" + loopend +
                         "}")
        
        if not filterType == 'frame':
            if filterType == 'measurement':
                meas, c, field = filterName.partition('.')
                subfield = 'this.results'
                chkfield = 'this.results[i].measurement_name == "%s"' % meas
                valfield = 'this.results[i].%s' % field
            elif filterType == 'framefeature':
                feat, c, field = filterName.partition('.')
                subfield = 'this.features'
                chkfield = 'this.features[i].featuretype == "%s"' % feat
                valfield = 'this.features[i].%s' % field
                
            if (filterFormat == 'numeric') or (filterFormat == 'datetime'):
                emit = "  emit(1, {min: val, max: val});"
            else:
                emit = ("  arr = {};"
                       "  arr[val] = 1;" 
                       "  emit(1, arr);")
        

            mapfn = Code("function () {" +
                         "  val = -1; " +
                         "  for (i = 0; i < " + subfield + ".length; i++) {" +
                         "    if (" + chkfield + ")" +
                         "      val = " + valfield + ";"+
                         emit +
                         "  }" +
                         "}")
            
        if (filterFormat == 'numeric') or (filterFormat == 'datetime'):
        #    pipeline.append({'$group': {'_id': 1, 'min': {'$min': '$' + collection + field}, 'max': {'$max': '$' + collection + field}}})
            reducefn = Code("function (key, values) {" +
                            "  ret = values[0]; " +
                            "  for (var i = 1; i < values.length; i++) { " +
                            "    if (values[i].min < ret.min) " +
                            "      ret.min = values[i].min; " +
                            "    if (values[i].max > ret.max) " +
                            "      ret.max = values[i].max; " + 
                            "  } " +
                            "  return ret;" +
                            "}")
        if (filterFormat == 'autofill'):
        #    pipeline.append({'$group': {'_id': 1, 'enum': {'$addToSet': '$' + collection + field}}})    
            reducefn = Code("function (key, values) {" +
                            "  ret = values[0]; " +
                            "  for (var i = 1; i < values.length; i++) { " +
                            "    for (idx in values[i]) {" + 
                            "      ret[idx] = 1;" + 
                            "    }"+
                            "  } " +
                            "  return ret;" +
                            "}")   
                

        res = Frame.objects.map_reduce(mapfn, reducefn, 'inline')
        doc = res.next()
        ret = {}
        if doc:
            if (filterFormat == 'autofill'):
                res = doc.value
                if '' in res:
                    del res['']
                if 'undefined' in res:
                    del res['undefined']
                keys = res.keys()
                keys.sort()
                ret['enum'] = keys
            else:
                ret = doc.value
        else:
            return {"error":"no matches found"}
        
        return ret
        
    
    def toCSV(self, rawdata):
        import StringIO
        import csv
        
        # csv libs assume saving to a file handle
        f = StringIO.StringIO()
        
        # Convert the dict to csv
        csvWriter = csv.writer(f)
        csvWriter.writerows(rawdata)
        
        # Grab the string version of the output
        output = f.getvalue()
        f.close()
        
        return output
        
    def toExcel(self, rawdata):
        import StringIO
        from xlwt import Workbook, XFStyle
        
        # Need a file handle to save to
        f = StringIO.StringIO()
        
        # Construct a workbook with one sheet
        wb = Workbook()
        s = wb.add_sheet('export')
        
        # Write the data
        for i, data in enumerate(rawdata):
            for j, val in enumerate(data):
                s.write(i, j, val)
                
        # Save the the string IO and grab the string data
        wb.save(f)
        output = f.getvalue()
        f.close()
        
        return output
        
    def keyNamesHash(self):
        # find all possible feature and result names
        
        featureKeys = {}
        resultKeys = {}
        
        for i in Inspection.objects:
            # Features can override their method name
            # To get actual plugin name, need to go through the inspection
            # Then use plugin to find the name of its printable fields
            plugin = i.get_plugin(i.method)
            if 'printFields' in dir(plugin):
                featureKeys[i.name] = plugin.printFields()
                # Always make sure the featuretype and inspection fields listed for other queries
                featureKeys[i.name].append('featuretype')
                featureKeys[i.name].append('inspection')
            else:
                featureKeys[i.name] = ['featuretype', 'inspection']
                
        # Becuase of manual measurements, need to look at frame results to figure out if numeric or string fields in place
        for m in Measurement.objects:
            # Have some manual measurements, which lack an actual plugin
            # Will have to ignore these for now, but log the issue                    
            try:
                plugin = m.get_plugin(m.method)
                if 'printFields' in dir(plugin):
                    resultKeys[m.name] = plugin.printFields()
                    resultKeys[m.name].append('measurement_name')
                else:
                    resultKeys[m.name] = ['measurement_name', 'measurement_id', 'inspection_id', 'string', 'numeric']
            except ValueError:
                # log.info('No plugin found for %s, using default fields' % m.method)
                resultKeys[m.name] = ['measurement_name', 'measurement_id', 'inspection_id', 'string', 'numeric']
        
        
        return featureKeys, resultKeys
        

    def keyNamesList(self):
        featureKeys, resultKeys = self.keyNamesHash()
        
        fieldNames = Frame.filterFieldNames()
                
        for key in featureKeys.keys():
            for val in featureKeys[key]:
                fieldNames.append(key + '.' + val)
            
        for key in resultKeys.keys():
            for val in resultKeys[key]:
                fieldNames.append(key + '.' + val)
            
        return fieldNames
        
    
    @classmethod
    def unEmbed(self, frame):
        feats = frame['features']
        newFeats = []
        for f in feats:
            newFeats.append(f['py/state'])
        frame['features'] = newFeats
        
        results = frame['results']
        newRes = []
        for r in results:
            newRes.append(r['py/state'])
        frame['results'] = newRes
        
        return frame
    
    def getField(self, field, keyParts):
        # This function recursively pulls apart the key parts to unpack the hashes and find the actual value
                
        if len(keyParts) == 1:
            return field.get(keyParts[0], None)
        else:
            return self.getField(field.get(keyParts.pop(0), {}), keyParts) 
    
    def inspectionIdToName(self, inspId):
        if inspId in self.names:
            return self.names[inspId]
        else:
            name = Inspection.objects(id=inspId)[0].name 
            self.names[inspId] = name
            return name
    
    def flattenFrame(self, frames):
        
        featureKeys, resultKeys = self.keyNamesHash()
        
        flatFrames = []
        for frame in frames:
            tmpFrame = {}
            
            # Grab the fields from the frame itself
            for key in Frame.filterFieldNames():
                if key == '_id' and 'id' in frame:
                    key = 'id'
                
                keyParts = key.split('.')
                tmpFrame[key] = self.getField(frame, keyParts)
                
            # Fields from the features
            for feature in frame.get('features', []):
                # If this feature has items that need to be saved
                inspection_name = self.inspectionIdToName(feature['inspection']) 
                if  inspection_name in featureKeys.keys():
                    # Pull up the relevant keys, named featuretype.field
                    for field in featureKeys[inspection_name]:
                        keyParts = field.split('.')
                        tmpFrame[feature['featuretype'] + '.' + field] = self.getField(feature, keyParts)
             
            # Fields from the results
            for result in frame.get('results', []):
                # If this result has items that need to be saved
                if result['measurement_name'] in resultKeys.keys():
                    for field in resultKeys[result['measurement_name']]:
                        keyParts = field.split('.')
                        tmpFrame[result['measurement_name'] + '.' + field] = self.getField(result, keyParts)
                            
            flatFrames.append(tmpFrame)
            
        return flatFrames
