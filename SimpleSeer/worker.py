from .Session import Session
from .realtime import ChannelManager
from . import models as M
from .util import load_plugins
from celery import Celery
from celery import task
from celery.exceptions import RetryTaskError


load_plugins()
session = Session("simpleseer.cfg")
host = 'mongodb://%s:%s/celery' % (session.mongo['host'], session.mongo['port'])
celery = Celery(broker=host, backend='mongodb')

@task()
def update_frame(frameid, inspection):
  '''
  **SUMMARY**
  This function is called using simpleseer worker objects.

  To start a worker create a simpleseer project, then from that directory run:

  >>> simpleseer worker

  Start another terminal window and then run the following from
  the project directory.  This will act as a task master to all the
  workers attached to the project, these workers can run on seperate
  machines as long as they point to the same database.
  If they are sharing the same database, they should have task delegated
  to them as long as they have the same code base running.

  >>> simpleseer shell
  >>> from SimpleSeer.commands.worker import update_frame

  To test that the function works correctly before shipping off to workers
  you just need to run:

  >>> update_frame((str(frame.id), 'inspection_name_here')

  Now to send the task to to the actual workers you run:

  >>> results = []
  >>> for frame in M.Frame.objects():
        results.append(update_frame.delay(str(frame.id), 'inspection_name_here'))

  The 'inspection_name_here' would be the inspection you want the
  worker to apply to the frame id passed in. For instance 'fastener'.

  To get back results from the workers you can now run:

  >>> [r.get() for r in results]

  Note that this will wait until that worker is finished with their task
  so this may take a while if one of the workers in the results list
  are not done.
  

  **PARAMETERS**
  * *frameid* - This is the actually id of the frame you want the worker to work on
  * *inspection* - The inspection method you want to run on the frame, the worker must have this plugin installed
  
  '''
  
  frame = M.Frame.objects(id=frameid)
  if not frame:
    print "Frame ID (%s) was not found" % frameid
    raise RetryTaskError("Frame ID (%s) was not found" % frameid)
  
  frame = frame[0]
  inspections = M.Inspection.objects(method = inspection)
  if not inspections:
    print 'Inspection method (%s) not found' % inspection
    return 'Inspection method (%s) not found' % inspection
  insp = inspections[0]

  print "analysing features for frame %s" % str(frame.id)
  try:
      img = frame.image
      if not img:
         Exception("couldn't read image")
  except:
      print "could not read image for frame %s" % str(frame.id)
      raise Exception("couldn't read image")

  if not img:
      print "image is empty"
      return "image is empty"

      
  if insp.id in [feat.inspection for feat in frame.features]:
      frame.features = [feat for feat in frame.features if feat.inspection != insp.id]
  

  frame.features += insp.execute(img)
  frame.save()
  print "saved features for frame %s" % str(frame.id)
  return 'frame %s update successful' % str(frame.id)
