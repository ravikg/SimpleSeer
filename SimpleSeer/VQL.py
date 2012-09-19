import models as M

from pyparsing import ParseException, Group, Suppress, Word, Optional, OneOrMore, ZeroOrMore, alphas, alphanums

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
        
        for group in parsed:
            if 'IN' in list(group):
                idx=list(group).index('IN')
                
                # First construct the parent object
                parentId = VQL.makeObjects(group[idx+1][0], group[idx+1][1])
                
                # Then construct the children
                for single in group[:idx]:
                    VQL.makeObjects(single[0], single[1], parentId)
                    
                # Then loop over any remaining objects
                if len(group) > idx + 2:
                    for single in group[:idx + 2]:
                        VQL.makeObjects(single[0], single[1])
                    
            else:
                for single in group:
                    VQL.makeObjects(single[0], single[1])
                
        return "YAY", 200

    @classmethod
    def makeObjects(self, inspPart, measPart, parent = None):
        inspection = inspPart
        measurements = measPart
        
        insp = M.Inspection()
        inspMethod = inspection[0]
        insp.name = inspMethod
        
        if not inspMethod in insp.register_plugins('seer.plugins.inspection'):
            return "Unknown method: %s" % inspMethod, 500
        insp.method = inspMethod
        
        if parent:
            insp.parent = parent
        
        if len(inspection) > 1:
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
        insp.save()
        
        for m in measurements:
            meas = M.Measurement()
            meas.name = m
            meas.method = m
            meas.inspection = insp.id
            meas.save()

        return insp.id
    
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
        inspectionHash = Group(keyOrKV + ZeroOrMore(Optional(Suppress(",")) + keyOrKV))
        inspection = name + Suppress("(") + Optional(inspectionHash) + Suppress(")")
        
        multiMeasurement = Suppress("[") + name + ZeroOrMore(Optional(Suppress(",")) + name) + Suppress("]")
        singleMeasurement = name
        measurement = Suppress(".") + (singleMeasurement | multiMeasurement)
        
        singleQuery = Group(Group(inspection) +  Group(Optional(measurement)))
        multiQuery = OneOrMore(singleQuery) + Optional("IN" + OneOrMore(singleQuery))

        groupedQuery = Optional(Group(multiQuery)) + ZeroOrMore(Group(Suppress("{") + multiQuery + Suppress("}"))) + Optional(Group(multiQuery))

        return groupedQuery
