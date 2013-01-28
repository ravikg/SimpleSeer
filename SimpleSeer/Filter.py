import logging

from .models.Frame import Frame
from .models.Inspection import Inspection
from .models.Measurement import Measurement
from datetime import datetime
from calendar import timegm

import mongoengine

import numpy as np

log = logging.getLogger(__name__)

class Filter():
    
    names = {}
    
    def getFrames(self, allFilters={}, skip=0, limit=float("inf"), sortinfo = {}, groupByField = '', collection='frame'):
        pipeline = []
        #frames = []
        #measurements = []
        #features = []
        
        if type(allFilters) == list or type(allFilters) == mongoengine.base.BaseList:
            allFilters = {'logic': 'and', 'criteria': allFilters}
        
        # Filter the data based on the filter parameters
        # Frame features are easy to filter, but measurements and features are embedded in the frame
        # so they need their own syntax to filter
        resCount = 1
        featCount = 0
        #for f in allFilters:
        #    if f['name'][:7] == 'results':
        #        resCount += 1
        #    elif f['name'][:8] == 'features':
        #        featCount += 1
            
        # Need to initialize the fields for the query.  Do this sparingly, as mongo has major memory limitations
        #pipeline += self.initialFields(projResult = resCount, projFeat = featCount)
       
        if groupByField: 
            pipeline += self.groupBy(groupByField)
        
        # Apply the sort criteria
        pipeline.append({'$match': self.conditional(allFilters['criteria'], allFilters['logic'])})
        
        pipeline += self.initialFields(projResult = resCount, projFeat = featCount)
       
        # Sort and skip/limit the results
        # Note: if the skip is negative, first sort by negative criteria, then re-sort regular
        if skip < 0:
            presort = sortinfo.copy()
            presort['order'] = -1 * int(presort['order'])  
            pipeline += self.sort(presort)

            skip = abs(skip)
            if limit == float("inf") or limit == None or limit > skip:
                limit = skip
                skip = 0
            else:
                skip = skip - limit
            pipeline.append({'$skip': skip})
            pipeline.append({'$limit': limit})
        
            pipeline += self.sort(sortinfo)
        else:
            pipeline += self.sort(sortinfo)
            if skip > 0:
                pipeline.append({'$skip': skip})
            if limit < float("inf") and not limit == None:
                pipeline.append({'$limit': limit})
        
        #for p in pipeline:
        #    print '%s' % str(p)
        
        #print collection
        # This is all done through mongo aggregation framework
        db = Frame._get_db()
        cmd = db.command('aggregate', collection, pipeline = pipeline)
        results = cmd['result']
        
        #return len(cmd['result']), results
        return -1, results    
        
    def groupBy(self, groupByField):
       proj = []
       
       # Have to unwind results so they get reconstructed as a single array when re-grouping
       proj.append({'$unwind': '$results'})
       proj.append({'$group': {'_id': '$' + groupByField, 'id': {'$first': '$id'}, 'metadata': {'$first': '$metadata'}, 'capturetime': {'$first': '$capturetime'}, 'capturetime_epoch': {'$first': '$capturetime_epoch'}, 'localtz': {'$first': '$localtz'}, 'results': {'$addToSet': '$results'}}})
 
       return proj
        
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
            p = self.rewindFields('features')
            fields.update(p)
            del fields['features']
        if projResult:
            p = self.rewindFields('results')
            fields.update(p)
            del fields['results']
            
        # Always want the 'id' field, which sometimes comes through as _id
        fields['id'] = '$_id'
        return [{'$project': fields}]
    
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
        
        # Only keep those keys requested
        featKeys, resKeys = self.keyNamesHash()
        
        if field == 'results':
            useKeys = resKeys
        elif field == 'features':
            useKeys = featKeys
            
        for key in useKeys:
            for f in useKeys[key]:
                proj[field + '.' + f] = 1
        
        return proj
    

    
    def conditional(self, filters, boolean):
        # This function generates the $match clauses for the aggregation

        allfilts = []
        for f in filters:    
            if 'logic' in f:
                allfilts.append(self.conditional(f['criteria'], f['logic']))
            else:
                nameParts = f['name'].split('.')
                
                name = f['name']
                if not f['type'] == 'frame':
                    name = '.'.join(nameParts[1:])
                
                # create the basic conditional
                comp = {}
                if 'eq' in f:
                    
                    # Need to convert the numbers into digits instead of strings
                    if (type(f['eq']) == str or type(f['eq']) == unicode) and f['eq'].isdigit() and not nameParts[0] == 'metadata':
                        f['eq'] = float(f['eq'])
                    
                    # Convert datetimes into epoch ms
                    if type(f['eq']) == datetime:
                        f['eq'] = datetime.fromtimestamp(f['eq'] / 1000)
                    
                    comp[name] = f['eq']
                if 'gt' in f or 'lt' in f:
                    parts = {}
                    if 'gt' in f:
                        parts['$gte'] = f['gt']
                    if 'lt' in f:
                        parts['$lte'] = f['lt']
                    comp[name] = parts
                if 'exists' in f:
                    comp[name] = {'$exists': True}
                
                # if not a frame-level filter, restrict to appropriate measurement/feature type
                if not f['type'] == 'frame':
                    if nameParts[0] == 'results':    
                        comp['measurement_name'] = f['type']
                    if nameParts[0] == 'features':
                        comp['featuretype'] = f['type']
                        
                #allfilts.append({'$match': {embedField: {'$elemMatch': comp}}})
                    allfilts.append({nameParts[0]: {'$elemMatch': comp}})
                else:
                    allfilts.append(comp)
                
        return {'$' + boolean: allfilts}
        
    def checkFilter(self, filterType, filterName, filterFormat):
        pipeline = []
        fieldParts = filterName.split('.')
        
        #project only those db fields required.  The field being queried and the "where" type clause
        project = {filterName: 1}
        if not filterType == 'frame':
            if fieldParts[0] == 'results':
                project['results.measurement_name'] = 1
            if fieldParts[0] == 'features':
                project['features.featuretype'] = 1
        pipeline.append({'$project': project})
        
        #if querying from results or features table, need to unwind to get individual records
        if fieldParts[0] == 'results' or fieldParts[0] == 'features':
            pipeline.append({'$unwind': '$' + fieldParts[0]})
        
        #match only relevant records:
        if not filterType == 'frame':
            if fieldParts[0] == 'results':
                pipeline.append({'$match': {'results.measurement_name': filterType}})
            if fieldParts[0] == 'features':
                pipeline.append({'$match': {'features.featuretype': filterType}}) 
            
        # numeric and datetime filters need the minimum and maximum values found    
        if (filterFormat == 'numeric') or (filterFormat == 'datetime'):
            pipeline.append({'$group': {'_id': 1, 'min': {'$min': '$' + filterName}, 'max': {'$max': '$' + filterName}}})
        
        # autofill filters create a set of unique values
        if (filterFormat == 'autofill'):
            pipeline.append({'$group': {'_id': 1, 'enum': {'$addToSet': '$' + filterName}}})    
            
        # Run the aggregation query by pulling the db connection from the Frame object
        db = Frame._get_db()
        cmd = db.command('aggregate', 'frame', pipeline = pipeline)
        ret = {}
        
        if len(cmd['result']) > 0:
            for key in cmd['result'][0]:
                # type will be list for autofills.  Sort the list of options
                if type(cmd['result'][0][key]) == list:
                    cmd['result'][0][key].sort()
                
                # If the type is datetime, turn it into epoch milliseconds
                if type(cmd['result'][0][key]) == datetime:
                    ms = cmd['result'][0][key].microsecond / 1000
                    cmd['result'][0][key] = timegm(cmd['result'][0][key].timetuple()) * 1000 + ms 
                    
                if not key == '_id':
                    ret[key] = cmd['result'][0][key]
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
                    resultKeys[m.name] = ['measurement_name', 'measurement_id', 'inspection_id', 'string', 'numeric', 'state', 'message']
            except ValueError:
                # log.info('No plugin found for %s, using default fields' % m.method)
                resultKeys[m.name] = ['measurement_name', 'measurement_id', 'inspection_id', 'string', 'numeric', 'state', 'message']
        
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
    
    def flattenFrame(self, frames, filters):
        flatFrames = []
        for frame in frames:
            tmpFrame = {'id': frame['id']}
            tmpFrame['capturetime_epoch'] = frame['capturetime_epoch']
            tmpFrame['capturetime'] = frame['capturetime']
            tmpFrame['localtz'] = frame['localtz']
        
            for filt in filters:
                #import pdb; pdb.set_trace()
                nameParts = filt['name'].split('.')
                if nameParts[0] == 'results':
                    nameParts = nameParts[1:]
                if True: #if nameParts[0] == 'results':
                    #rest = '.'.join(nameParts[1:])
                    #key = filt['type'] + '.' + rest
                    for res in frame.get('results', []):
                        if res['measurement_name'] == filt['type']:
                            key = '.'.join(nameParts)
                            # quick hack to always make it numeric
                            #key = 'numeric'
                            val = self.getField(res, nameParts) 
                            tmpFrame["%s.%s" % (filt['type'], key)] = val
                    
            flatFrames.append(tmpFrame)
            
        return flatFrames
        
