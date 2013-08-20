import flask
import unittest

from SimpleSeer import views, crud
from SimpleSeer.tests import utils

class Test(unittest.TestCase):

    def create_app(self):
        utils.register_mim_connection()
        app = flask.Flask(__name__)
        app.config['TESTING'] = True
        views.route.register_routes(app)
        crud.register(app)
        return app

    def test_get_index(self):
        result = self.client.get('/')
        self.assertEqual(result.content_type, 'text/html; charset=utf-8')