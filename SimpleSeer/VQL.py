import models as M

from pyparsing import ParseException, Group, Suppress, Word, Literal, Optional, ZeroOrMore, alphas, alphanums

import logging
log = logging.getLogger(__name__)

class VQL:
        
    @classmethod
    def execute(self, query):
        
        g = VQL.grammar()
        
        try:
            parsed = g.parseString(query)
        except ParseException, e:
            return "Parse Error, line %s, col %s" % (e.loc, e.column), 500
        
        inspection = parsed[0]
        measurements = parsed[1]
        
        insp = M.Inspection()
        inspMethod = inspection[0]
        insp.name = inspMethod
        
        if not inspMethod in insp.register_plugins('seer.plugins.inspection'):
            return "Unknown method: %s" % inspMethod, 500
        insp.method = inspMethod
        
        inspParams = {}
        for p in inspection[1]:
            if len(p) > 1:
                inspParams[p[0]] = p[1]
            else:
                plugin = insp.get_plugin(insp.method)
                reverse = plugin.reverseParams()
                if p[0] not in reverse:
                    return "Unrecognized shortcut parameter: %s" % p[0], 500
                inspParams[reverse[p[0]]] = p[0]
        insp.parameters = inspParams
        print insp
        insp.save()
        
        for m in measurements:
            meas = M.Measurement()
            meas.name = m
            meas.method = m
            meas.inspection = insp.id
            print meas
            meas.save()
        
        return str(inspMethod) + "___" + str(inspParams), 200
    
    @classmethod
    def reverse(self):
        
        query = []
        for insp in M.Inspection.objects:
            measNames = []
            for meas in M.Measurement.objects(inspection=insp.id):
                measNames.append(meas.method)
            query.append("%s(%s).[%s]" % (insp.method, str(insp.parameters).replace('{', '').replace('}', ''), ",".join(measNames)))
        
        return " ".join(query)
    
    @classmethod
    def grammar(self):
        
        name = Word(alphanums + ".") 
        
        keyOrKV = Group(name + Optional(Suppress(":") + name)) 
        inspectionHash = Group(keyOrKV + ZeroOrMore(Suppress(",") + keyOrKV))
        inspection = name + Suppress("(") + inspectionHash + Suppress(")")
        
        multiMeasurement = Suppress("[") + name + ZeroOrMore(Suppress(",") + name) + Suppress("]")
        singleMeasurement = name
        measurement = Suppress(".") + (singleMeasurement | multiMeasurement)
        
        query = Group(inspection) +  Group(Optional(measurement))

        return query
