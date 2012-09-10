from SimpleSeer.Filter import Filter

import logging

import mongoengine
from .base import SimpleDoc

import numpy as np
import pandas as pd

log = logging.getLogger(__name__)

class Predictive(SimpleDoc, mongoengine.Document):
    
    filterFields = mongoengine.DictField()
    dependent = mongoengine.StringField()
    independent = mongoengine.ListField()
    method = mongoengine.StringField()
    betas = mongoengine.ListField()
    
    def getData(self):
        f = Filter()
        tot, frames = f.getFrames(self.filterFields)
        df = pd.DataFrame(f.flattenFeature(frames))
        
        deps = df[self.dependent]
        inds = pd.DataFrame({var:df[var] for var in self.independent})
		    		
        return inds, deps
        
    def transformData(self, inds):
        from calendar import timegm
        
        for field in inds:
            if inds[field].dtype == str:
                # Turn string variables into categorical variables
                for element in inds[field].unique():
                    inds[i] = field == i 
            if inds[field].dtype == object:
                # Assume objects are datetimes, which need to be converted to epoch seconds
                inds[field] = inds[field].apply(lambda x: timegm(x.timetuple()))
        
        return inds
                
    def estimate(self, deps, inds):
        from numpy import dot, linalg
        
        model = pd.ols(y = deps, x = inds)
        
        return model.betas.values
        
    def execute(self, frame):
        
        tally = 0
        for beta, field in zip(self.betas, self.indendent):
            tally += frame[field] * beta
            
        return tally
    
    def update(self):
        
        inds, deps = self.getData()
        inds = self.transformData(inds)
        self.betas = self.estimate(deps, inds)
        self.save()

    def partial(self, deps, inds, partial):
        from numpy import dot, linalg
        
        tmp = {}
        for var in inds:
            if var != partial: temp[var] = inds[var]
            
        sInds = pd.DataFrame({var:df[var] for var in self.independent})
        model1 = pd.ols(y = deps, x = sInds)
        model2 = pd.ols(y = inds[partial], x = sInds)
        
        return model1.resid, model2.resid

class NelsonRules:
    
    # Note True value indicates failure
    
    @classmethod
    def convolve(self, arr, windowSize, thresh = None):
        # Do the convolutions in calculating the rules
        # In this case, that really just means computing moving averages
        # To find the number of matches
        # E.g., if the avg is 1, then all elements in the window matched.  If .5, then half matched.
        
        if not thresh:
            thresh = 1
        
        window = np.repeat(1.0 / windowSize, windowSize)
        arrConv = np.convolve(arr, window)[:-(windowSize - 1)]
        
        # Can get burned by floating point precision when testing equality to one
        # Note: value will never be greater than one, so shaving off eps will solve problem
        adjThresh = thresh - np.finfo(float).eps
        
        return len(arrConv[arrConv >= adjThresh])
    
    @classmethod
    def rule1(self, points, mean, sd):
        # If a point is more than 3 standard deviations from mean
        # Assumes that points is a numpy array
        upper = mean + (3 * sd)
        lower = mean - (3 * sd)
        
        u = len(points[points > upper])
        l = len(points[points < lower])
        
        return (u + l) > 3
        
    @classmethod    
    def rule2(self, points, mean):
        # if 9 or more points in a row lie on same side of mean
        # assumes points is a numpy array
        
        aboveArr = points > mean
        belowArr = points < mean
        
        a = NelsonRules.convolve(aboveArr, 9)
        b = NelsonRules.convolve(belowArr, 9)
        
        return a + b > 0
        
    @classmethod
    def rule3(self, points):
        # 6 or more increasing or decreasing
        
        incArr = points[0:-1] > points[1:len(points)]
        decArr = points[0:-1] < points[1:len(points)]
        
        # 5 gt or lt comparisons will involve 6 points, so window size is 5
        i = NelsonRules.convolve(incArr, 5)
        d = NelsonRules.convolve(decArr, 5)
        
        return i + d > 0
            
    @classmethod
    def rule4(self, points):
        # 14 or more points alternating
        
        incArr = points[0:-1] > points[1:len(points)]
        altArr = (incArr[0:-1] != incArr[1:len(incArr)])
        
        # 14 alternating points requires 12 comparisons with the previous two points
        alt = NelsonRules.convolve(altArr, 12)
        
        return alt > 0
        
    @classmethod
    def rule5(self, points, mean, sd):
        # two out of three points in a row more than 2 standard devs from mean
        
        aboveThresh = mean + 2*sd
        belowThresh = mean - 2*sd
        
        aboveArr = points > aboveThresh
        belowArr = points < belowThresh
        
        a = NelsonRules.convolve(aboveArr, 3, (2/3))
        b = NelsonRules.convolve(belowArr, 3, (2/3))
        
        return a + b > 0
        
    @classmethod
    def rule6(self, points, mean, sd):
        # four out of five points in a row more than 1 standard dev from mean
        
        aboveThresh = mean + sd
        belowThresh = mean - sd
        
        aboveArr = points > aboveThresh
        belowArr = points < belowThresh
        
        a = NelsonRules.convolve(aboveArr, 5, (4/5))
        b = NelsonRules.convolve(belowArr, 5, (4/5))
        
        return a + b > 0
        
    @classmethod
    def rule7(self, points, mean, sd):
        # 15 or more points in a row within 1 standard dev from mean
        
        upperThresh = mean + sd
        lowerThres = mean - sd
        
        belowUpperArr = points < upperThresh
        aboveLowerArr = points > lowerThresh
        withinArr = belowUpperArr and aboveLowerArr
        
        count = NelsonRules.convolve(withinArr, 15)
        
        return count > 0
        
    @classmethod
    def rule8(self, points, mean, sd):
        # 8 points in a row with none within a standard deviation of mean
        
        upperThresh = mean + sd
        lowerThres = mean - sd
        
        aboveUpperArr = points > upperThresh
        belowLowerArr = points < lowerThresh
        
        outsideArr = aboveUpperArr or belowLowerArr
        
        count = NelsonRules.convole(outsideArr, 8)
        
        return count > 0
        
