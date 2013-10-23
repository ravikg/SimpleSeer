import unittest
from SimpleSeer.Session import Session
from SimpleSeer import validators as V


class Test(unittest.TestCase):

    testValues = {
        "Invalid No Default":"invalid integer",
        "Invalid Default":"invalid integer",
        #"Missing Default":"do not uncomment",
        #"Missing No Default":"do not uncomment",
        "Valid":"valid",
        "Invalid Regex No Default":"not valid",
        "Invalid Regex Default":"not valid",
        "Valid Regex":"valid"
    }

    def setUp(self):
        import logging
        self.logger = logging.getLogger()
        self.logger.setLevel("INFO")
        self.sess = Session()
        settings = self.sess.read_config()
        self.sess._config = settings

    def test_no_modelschema(self):
        self.sess._config['modelschema'] = {}
        del self.sess._config['modelschema']
        self.assertEqual(self.sess._config.get('modelschema','Schema Still Set'),'Schema Still Set')
        r = V.StrictJSON()._to_python(self.testValues)
        #TODO: should check log for "No matchKey for custom schema in StrictJSON validator"
        self.assertEqual(r,{})

    def test_no_matchKey(self):
        self.sess._config['modelschema'] = {}
        self.assertEqual(Session().get_config()['modelschema'], self.sess._config['modelschema'])
        r = V.StrictJSON(schemakey="metadata")._to_python(self.testValues)
        #TODO: should check log for "WARNING  no modelschema key "metadata" found in simpleseer config"
        self.assertEqual(r,{})


    def test_invalid_no_default(self):
        self.sess._config['modelschema'] = {
            'metadata': {
                'Invalid No Default': {
                    'validator': 'int'
                }
            }
        }
        self.assertEqual(Session().get_config()['modelschema'], self.sess._config['modelschema'])
        r = V.StrictJSON(schemakey="metadata")._to_python(self.testValues)
        self.assertEqual(r,{})

    def test_invalid_default(self):
        self.sess._config['modelschema'] = {
            'metadata': {
                'Invalid Default': {
                    'validator': 'int',
                    'args': {
                        'if_invalid': 1234
                    }
                }
            }
        }
        self.assertEqual(Session().get_config()['modelschema'], self.sess._config['modelschema'])
        r = V.StrictJSON(schemakey="metadata")._to_python(self.testValues)
        self.assertEqual(r,{"Invalid Default":1234})

    def test_missing_default(self):
        self.sess._config['modelschema'] = {
            'metadata': {
                'Missing Default': {
                    'validator': 'string',
                    'args': {
                        'if_missing': 'fooby'
                    }
                }
            }
        }
        self.assertEqual(Session().get_config()['modelschema'], self.sess._config['modelschema'])
        r = V.StrictJSON(schemakey="metadata")._to_python(self.testValues)
        self.assertEqual(r,{"Missing Default":"fooby"})

    def test_missing_no_default(self):
        self.sess._config['modelschema'] = {
            'metadata': {
                'Missing No Default': {
                    'validator': 'string'
                }
            }
        }
        self.assertEqual(Session().get_config()['modelschema'], self.sess._config['modelschema'])
        r = V.StrictJSON(schemakey="metadata")._to_python(self.testValues)
        self.assertEqual(r,{})

    def test_valid(self):
        self.sess._config['modelschema'] = {
            'metadata': {
                'Valid': {
                    'validator': 'string'
                }
            }
        }
        self.assertEqual(Session().get_config()['modelschema'], self.sess._config['modelschema'])
        r = V.StrictJSON(schemakey="metadata")._to_python(self.testValues)
        self.assertEqual(r,{"Valid":"valid"})

    def test_invalid_regex_no_default(self):
        self.sess._config['modelschema'] = {
            'metadata': {
                'Invalid Regex No Default': {
                    'validator': 'regex',
                    'args': {
                        'regex': '^[a-z]+$'
                    }
                }
            }
        }
        self.assertEqual(Session().get_config()['modelschema'], self.sess._config['modelschema'])
        r = V.StrictJSON(schemakey="metadata")._to_python(self.testValues)
        self.assertEqual(r,{})

    def test_invalid_regex_default(self):
        self.sess._config['modelschema'] = {
            'metadata': {
                'Invalid Regex Default': {
                    'validator': 'regex',
                    'args': {
                        'if_invalid': 'valid',
                        'regex': '^[a-z]+$'
                    }
                }
            }
        }
        self.assertEqual(Session().get_config()['modelschema'], self.sess._config['modelschema'])
        r = V.StrictJSON(schemakey="metadata")._to_python(self.testValues)
        self.assertEqual(r,{"Invalid Regex Default":"valid"})

    def test_valid_regex(self):
        self.sess._config['modelschema'] = {
            'metadata': {
                'Valid Regex': {
                    'validator': 'regex',
                    'args': {
                        'regex': '^[a-z]+$'
                    }
                }
            }
        }
        self.assertEqual(Session().get_config()['modelschema'], self.sess._config['modelschema'])
        r = V.StrictJSON(schemakey="metadata")._to_python(self.testValues)
        self.assertEqual(r,{"Valid Regex":"valid"})
