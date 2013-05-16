import mongoengine
import calendar

from .base import SimpleDoc, SimpleEmbeddedDoc

class ResultEmbed(SimpleEmbeddedDoc, mongoengine.EmbeddedDocument):
    _jsonignore = ('result_id', 'inspection_id', 'measurement_id')
    result_id = mongoengine.ObjectIdField()
    numeric = mongoengine.FloatField()
    string = mongoengine.StringField()
    featureindex = mongoengine.IntField()
    inspection_id = mongoengine.ObjectIdField()
    inspection_name = mongoengine.StringField()
    measurement_id = mongoengine.ObjectIdField()
    measurement_name = mongoengine.StringField()
    state = mongoengine.IntField()
    message = mongoengine.StringField()

    def __repr__(self):
        # Make this compatible with embedded objects from worker (no _data)
        # The problem occurs with results from workers that are not yet saved in the database
        if '_data' in self:
            inspName = self.inspection_name
            measName = self.measurement_name
            numeric = self.numeric
            string = self.string
        else:
            inspName = self.__dict__['inspection_name']
            measName = self.__dict__['measurement_name']
            numeric = self.__dict__['numeric']
            string = self.__dict__['string']
            
        return '<ResultEmbed %s:%s = (%s,%s)>' % (
            inspName, measName, numeric, string)

    def get_or_create_result(self):
        result, created =  Result.objects.get_or_create(
            auto_save=False, id=self.result_id)
        if created:
            result.numeric = self.numeric
            result.string = self.string
            result.inspection_id=self.inspection_id
            result.inspection_name = self.inspection_name
            result.measurement_id = self.measurement_id
            result.measurement_name = self.measurement_name
        return result, created


