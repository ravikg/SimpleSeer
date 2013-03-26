from .Session import Session

session = Session(".")

#BROKER_URL = 'mongodb://%s:%d/%s' % (session.mongo['host'], session.mongo['port'], session.database)
BROKER_URL = 'amqp://%s//' % session.rabbitmq
CELERY_IMPORTS = ("SimpleSeer.worker",)
#CELERY_RESULT_BACKEND = "mongodb"
#CELERY_MONGODB_BACKEND_SETTINGS = dict(
#   host = session.mongo['host'],
#   port = int(session.mongo['port']),
#   database = session.database,
#   taskmeta_collection = "celery_taskmeta",
#   user = '',
#   password = '')
