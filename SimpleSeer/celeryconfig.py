from .Session import Session

session = Session(".")

BROKER_URL = 'amqp://%s//' % session.rabbitmq
CELERY_IMPORTS = ("SimpleSeer.worker",)
CELERY_RESULT_BACKEND = "amqp"
#CELERY_TASK_SERIALIZER = 'json'
#CELERY_RESULT_SERIALIZER = 'json'
