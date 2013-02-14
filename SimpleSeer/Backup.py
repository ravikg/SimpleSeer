from yaml import load, dump
#from .base import jsonencode, jsondecode

import os
from socket import gethostname

from datetime import datetime

import models as M

from .realtime import ChannelManager
import mongoengine
from bson import ObjectId

import logging
log = logging.getLogger(__name__)

class Backup:
    
    @classmethod
    def exportAll(overwrite = True):
        # Serializes (json-ifies) non-data objects 
        # By default saves to file names seer_export.json, overwriting previous file
        # Pass overwrite = False to append timestamp to file name (preventing overwrite of previous file)
    
        exportable = [{'name': 'Inspection', 'sort': 'method'}, 
                      {'name': 'Measurement', 'sort': 'method'}, 
                      {'name': 'Watcher', 'sort': 'name'},
                      {'name': 'OLAP', 'sort': 'name'}, 
                      {'name': 'Chart', 'sort': 'name'}, 
                      {'name': 'Dashboard', 'sort': 'name'},
                      {'name': 'Context', 'sort': 'name'}]
        
        toExport = []
        for exportDef in exportable:
            exportName = exportDef['name']
            objClass = M.__getattribute__(exportName)
            for obj in objClass.objects.order_by(exportDef['sort']):
                okToExport = True
                if (type(obj) == M.OLAP or type(obj) == M.Chart) and obj.transient:
                    # Don't export transient olap
                    okToExport = False
                    
                if okToExport:
                    # Encode to get rid of mongoengine types
                    objDict = obj._data
                    try:
                        objDict.pop('updatetime')
                    except:
                        pass
                    
                    exportDict = {}
                    for key, val in objDict.iteritems():
                        if key == None:
                            exportDict['id'] = str(val)
                        elif key and val != getattr(objClass, key).default:
                            exportDict[key] = Backup.toPythonType(val)
                        
                    toExport.append({'type': exportName, 'obj': exportDict})
        yaml = dump(toExport, default_flow_style=False)
        
        ts = ''
        if not overwrite:
            ts = '_%s' % datetime.utcnow().strftime('%Y%m%d%H%M%S')
        filename = 'seer_export%s.yaml' % ts
        
        log.info('Logging to %s' % filename)
        f = open(filename, 'w')
        f.write(yaml)
        f.close()
        
    @classmethod
    def toPythonType(self, obj):
        from bson import ObjectId
        
        # Convert various unicode, mongoengine, and other formats into basic python types
        if type(obj) == unicode:
            return str(obj)
        elif type(obj) == ObjectId:
            return str(obj)
        elif type(obj) == dict:
            return { str(key): Backup.toPythonType(val) for key, val in obj.iteritems() }    
        elif type(obj) == list:
            return [ Backup.toPythonType(val) for val in obj ]
        else:
            return obj
        
    @classmethod
    def listen(self):
        
        log.info('Subscribing to meta/ channel for updates')
        
        cm = ChannelManager()
        sock = cm.subscribe('meta/')
        
        while True:
            cname = sock.recv()
            log.info('Update from %s, exporting metadata' % cname)
            Export.exportAll()

    @classmethod
    def importAll(self, fname=None, clean=False, skip=False, checkOnly=False):
        from .models.MetaSchedule import MetaSchedule
        
        if clean:
            log.info('Clear the olap cache')
            M.Frame._get_db().olap_cache.remove()
            
            log.info('Removing old features and results')
            M.Frame._get_db().frame.update({}, {'$set': {'results': [], 'features': []}}, multi=True)
            M.Frame._get_db().metaschedule.remove()
           
            log.info('Stopping celery tasks')
            from celery import Celery
            from . import celeryconfig
            celery = Celery()
            celery.config_from_object(celeryconfig)
            res = celery.control.purge()
            log.info('Stopped %s celery tasks' % res)
 
            log.info('Removing old metadata')
            M.Inspection.objects.delete()
            M.Measurement.objects.delete()
            M.OLAP.objects.delete()
            M.Chart.objects.delete()
            M.Dashboard.objects.delete()
            M.Context.objects.delete()
        elif not checkOnly:
            log.info('Preserving old metadata.  Any new results/features will be appended to existing results/features')
        
        if not fname:
            fname = 'seer_export.yaml'
            
        log.info('Checking meta in file %s' % fname)
        try:
            f = open(fname, 'r')
            yaml = f.read()
            f.close()
        except IOError as err:
            log.warn('Import failed: %s' % err.strerror)
            return
            
        objs = load(yaml)
                
        altMeta = gethostname() + '_seer_export.yaml'
        if os.path.isfile(altMeta):
            log.info('Overriding meta with %s' % altMeta)
            altMetaList = load(open(altMeta))
        
            for alt in altMetaList:
                # First, try to find a corresponding entry to update
                found = False
                for obj in objs:
                    if alt['type'] == obj['type'] and alt['obj']['id'] == obj['obj']['id']:
                        found = True
                        obj['obj'].update(alt['obj'])
                
                # If no entry found, append the result
                if not found:
                    objs.append(alt)
        
        ms = MetaSchedule()
        #log.info('Loading new metadata')
        for o in objs:
            try:
                model = M.__getattribute__(o['type']).objects.get(id=o['obj']['id'])
                #log.info('Updating %s' % model)
            except:
                model = M.__getattribute__(o['type'])()
                model._data[None] = o['obj']['id']
                #log.info('Creating new %s' % o['type'])
            
            for k, v in o['obj'].iteritems():
                # Enqueue items for backfill only if method changed or if clean
                if k == 'method' and (v != getattr(model, 'method') or clean) and not skip:
                    if o['type'] == 'Measurement':
                        ms.enqueue_measurement(model.id)
                    else:
                        ms.enqueue_inspection(model.id)
                
                if k != 'id':
                    if type(getattr(getattr(M, (o['type'])), k)) == mongoengine.base.ObjectIdField:
                        model.__setattr__(k, ObjectId(v))
                    else:
                        model.__setattr__(k, v)
                
            
            if not checkOnly:
                # When saving make sure measurements dont re-run their backfill
                if o['type'] == 'Measurement':
                    model.save(skipBackfill=True)
                else:
                    model.save()
            else:
                same = False
                for existing in M.__getattribute__(o['type']).objects:
                    if model == existing:
                        same = True
                        
                if same == False:
                    log.warn('****************************************************************')
                    log.warn('* WARNING: ')
                    log.warn('* Metadata does not match current system')
                    log.warn('* ' + model.__repr__())
                    log.warn('* Exporting changes to meta will overwrite existing settings')
                    log.warn('****************************************************************')
                
        
                    
    
        if not skip:
            log.info('Beginning backfill')
            ms.run()
        elif not checkOnly:
            log.info('Skipping backfill')
