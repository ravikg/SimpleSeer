from yaml import load, dump
from datetime import datetime

import models as M

from .realtime import ChannelManager
import mongoengine

import logging
log = logging.getLogger(__name__)

class Backup:
    
    @classmethod
    def exportAll(overwrite = True):
        # Serializes (json-ifies) non-data objects 
        # By default saves to file names seer_export.json, overwriting previous file
        # Pass overwrite = False to append timestamp to file name (preventing overwrite of previous file)
    
        exportable = ['Inspection', 'Measurement', 'Watcher', 'OLAP', 'Chart', 'Dashboard', 'Context']
        
        toExport = []
        
        for exportName in exportable:
            objClass = M.__getattribute__(exportName)
            for obj in objClass.objects:
                
                okToExport = True
                if (type(obj) == M.OLAP or type(obj) == M.Chart) and obj.transient:
                    # Don't export transient olap
                    okToExport = False
                    
                if okToExport:
                    objDict = obj.__dict__
                    # yaml does not take kindly to mongoengine BaseLists in the _data
                    # so convert them to lists
                    if '_data' in objDict:
                        for k, v in objDict['_data'].iteritems():
                            if type(v) == mongoengine.base.BaseList:
                                objDict['_data'][k] = list(v)
                        
                    # yaml dump does not take kindly to mongoeninge docs, so just store the dict
                    toExport.append({'type': exportName, 'obj': objDict})
        
        yaml = dump(toExport)
        
        ts = ''
        if not overwrite:
            ts = '_%s' % datetime.utcnow().strftime('%Y%m%d%H%M%S')
        filename = 'seer_export%s.yaml' % ts
        
        log.info('Logging to %s' % filename)
        f = open(filename, 'w')
        f.write(yaml)
        f.close()
        
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
    def importAll(self, fname=None, clean=False, skip=False):
        from .models.MetaSchedule import MetaSchedule
        
        if clean:
            log.info('Removing old features and results')
            M.Frame._get_db().frame.update({}, {'results': [], 'features': []})
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
        else:
            log.info('Preserving old metadata.  Any new results/features will be appended to existing results/features')
        
        if not fname:
            fname = 'seer_export.yaml'
            
        log.info('Importing from %s' % fname)
        try:
            f = open(fname, 'r')
            yaml = f.read()
            f.close()
        except IOError as err:
            log.warn('Import failed: %s' % err.strerror)
            return
            
        objs = load(yaml)        
        
        ms = MetaSchedule()
        log.info('Loading new metadata')
        for o in objs:
            model = M.__getattribute__(o['type'])()
            
            for k, v in o['obj']['_data'].iteritems():
                if k is not None and v is not None:
                    model.__setattr__(k, v)
            model.id = o['obj']['_data'][None]
            
            # Delete previous versions, based on overlapping names
            prev = M.__getattribute__(o['type']).objects()
            found = False
            for p in prev:
                if p == model:
                    found = True
                    log.info('Skipping existing %s: %s' % (o['type'], model.name))
            
            if not found:                    
                log.info('Adding new  %s %s' % (o['type'], model.name))
                # Enqueue items for backfill
                if o['type'] == 'Measurement':
                    if not skip:
                        ms.enqueue_measurement(model.id)
                    model.save(skipBackfill=True)
                elif o['type'] == 'Inspection':
                    if not skip:
                        ms.enqueue_inspection(model.id)
                    model.save()
                else:
                    model.save()
        
        if not skip:
            log.info('Beginning backfill')
            ms.run()
        else:
            log.info('Skipping backfill')
