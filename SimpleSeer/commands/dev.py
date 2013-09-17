from .base import Command
from yaml import load, dump
from SimpleSeer.models import Frame, FrameFeature, ResultEmbed, Measurement, Inspection
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
        subparser.add_argument("-m", "--metadata", dest="metadata", default="{}",  help="metadata to apply to each generated frame")


    def run(self):
        import logging
        logging.basicConfig(level=logging.DEBUG)
        log = logging.getLogger()
        self.options.metadata = eval(self.options.metadata)
        log.info("Checking meta in file {}".format(self.options.yaml_path))
        try:
            f = open(self.options.yaml_path, 'r')
            yaml = f.read()
            f.close()
        except IOError as err:
            log.warn("Import failed: {}, generate sample yaml with simpleseer generatedevyaml".format(err.strerror))
            return
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
                    _bound = randrange(0,2)
                    if _bound:
                        bx = int(bounds[0]) - randrange(1,self.options.tolerance)
                        by = int(bounds[1]) - randrange(1,self.options.tolerance)
                    else:
                        bx = int(bounds[0]) + randrange(1,self.options.tolerance)
                        by = int(bounds[1]) + randrange(1,self.options.tolerance)
                    return randrange(bx, by)


        def _gen_frames(options, passframe):
            for x in range(1,int(self.options.frame_passes)):
                f =  Frame(capturetime=datetime.datetime.now())
                f.features = []
                for inspection_id, ff_values in objs["FrameFeatures"].iteritems():
                    ff = FrameFeature()
                    for tol_name, tol_values in ff_values.iteritems():
                        ff.featuredata[tol_name] = _gen_rnd_vals(tol_values, passframe)
                    ff.inspection = inspection_id
                    f.features.append(ff)
                f.metadata = options.metadata
                f.save()

        def _gen_frames_meas(options, passframe):
            for x in range(1,int(self.options.frame_passes)):
                f =  Frame(capturetime=datetime.datetime.now())
                f.results = []
                for measurement_id, re_values in objs["ResultEmbed"].iteritems():
                    result = ResultEmbed()
                    for tol_name, tol_values in re_values.iteritems():
                        result.numeric = _gen_rnd_vals(tol_values, passframe)
                    mObj = Measurement.objects.get(id=measurement_id)
                    iObj = Inspection.objects.get(id=mObj.inspection)
                    result.measurement_id = measurement_id
                    result.inspection_id = mObj.inspection
                    result.measurement_name = mObj.name
                    result.inspection_name = iObj.name
                    f.results.append(result)
                f.metadata = options.metadata
                f.save()

        log.info("Generating {} passes".format(self.options.frame_passes))
        _gen_frames(self.options, True)
        _gen_frames_meas(self.options, True)

        log.info("Generating {} failing frames".format(self.options.frame_fails))
        _gen_frames(self.options, False)
        _gen_frames_meas(self.options, False)

class GenerateDevYAMLCommand(DevCommand):

    def run(self):
        toExport = {'FrameFeatures': {'50002eee598e1e2ba4000000': {'box': [[[0, 10], [30, 40]], [[0, 10], [400, 500]]], 'curve': [10, 12], 'height': [100, 130]}}}
        yaml = dump(toExport, default_flow_style=False)        
        f = open("dev.yaml", 'w')
        f.write(yaml)
        f.close()
        return yaml
