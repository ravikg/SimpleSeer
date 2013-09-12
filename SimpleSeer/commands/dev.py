from .base import Command
from yaml import load, dump
from SimpleSeer.models import Frame, FrameFeature 
import datetime
from random import randrange

class DevCommand(Command):
    "Simple management tasks that don't require SimpleSeer context"
    use_gevent = False

    def configure(self, options):
        self.options = options


class CreateTestFramesCommand(DevCommand):

    def __init__(self, subparser):
        subparser.add_argument("-p", "--pass", dest="frame_passes", default=10, help="Number of passing frames to generate")
        subparser.add_argument("-f", "--fail", dest="frame_fails", default=10,  help="Number of failed frames to generate")
        subparser.add_argument("-t", "--tolerance", dest="tolerance", default=3, help="On failed frames, this number indicates how much to deviate from the passing bounds")
        subparser.add_argument("-y", "--yaml", dest="yaml_path", default="dev.yaml",  help="Path to yaml file containing the pass/fail data")

    def run(self):
        import logging
        log = logging.getLogger(__name__)

        log.info("Checking meta in file {}".format(self.options.yaml_path))
        try:
            f = open(self.options.yaml_path, 'r')
            yaml = f.read()
            f.close()
        except IOError as err:
            log.warn("Import failed: {}, generateing sample yaml".format(err.strerror))
            yaml = self.gen_yaml()
        objs = load(yaml)

        def _gen_rnd_vals(bounds,passframe=True):
            if type(bounds[0]) == list:
                retVal = []
                for subtol in bounds:
                    retVal.append(_gen_rnd_vals(subtol,passframe))
                return retVal
            else:
                if passframe:
                    return randrange(int(bounds[0]),int(bounds[1]))
                else:
                    _bound = randrange(0,1)
                    if _bound:
                        bx = int(bounds[0]) - randrange(1,self.options.tolerance)
                        by = int(bounds[1]) - randrange(1,self.options.tolerance)
                    else:
                        bx = int(bounds[0]) + randrange(1,self.options.tolerance)
                        by = int(bounds[1]) + randrange(1,self.options.tolerance)
                    return randrange(bx, by)


        def _gen_frames(passframe):
            for x in range(1,int(self.options.frame_passes)):
                f =  Frame(capturetime=datetime.datetime.now())
                f.features = []
                for ff_name, ff_values in objs["FrameFeatures"].iteritems():
                    ff = FrameFeature()
                    for tol_name, tol_values in ff_values.iteritems():
                        ff.featuredata[tol_name] = _gen_rnd_vals(tol_values, passframe)
                    f.features.append(ff)
                f.save()

        log.info("Generating {} passes".format(self.options.frame_passes))
        _gen_frames(True)

        log.info("Generating {} failing frames".format(self.options.frame_fails))
        _gen_frames(False)

    def gen_yaml(self):
    	toExport = {'FrameFeatures': {'tester': {'box': [[[0, 10], [30, 40]], [[0, 10], [400, 500]]], 'curve': [10, 12], 'height': [100, 130]}}}
        yaml = dump(toExport, default_flow_style=False)        
        f = open(self.options.yaml_path, 'w')
        f.write(yaml)
        f.close()
        return yaml
