from SimpleCV import *
from sklearn import tree
from sklearn import svm
import marshal
path = "./data/"
dirlist = ["angle","flat","long"]
split = 0.5

def CreateDataSets(path,dirlist,split):
    truth = []
    test = []
    for d in dirlist:
        full_path = path+d+"/"
        imset = ImageSet(full_path)
        sz = len(imset)
        split_pt  = int(sz*split)
        temp_truth = imset[0:split_pt]
        temp_test = imset[split_pt:]
        truth.append(temp_truth)
        test.append(temp_test)
    return truth,test

def GenerateFeatureVector(img):
    result = []
    mask = img.threshold(20).dilate(2)
    # UH = mask.crop(0,0,img.width,img.height/2).meanColor()[0]
    # BH = mask.crop(0,img.height/2,img.width,img.height/2).meanColor()[0]
    # RH = mask.crop(0,img.width/2,img.width/2,img.height).meanColor()[0]
    # LH = mask.crop(0,0,img.width/2,img.height).meanColor()[0]
    
    # result.append(UH)
    # result.append(BH)
    # result.append(RH)
    # result.append(LH)
    b = img.findBlobsFromMask(mask,minsize=250)
    if( b is not None ):
        b = b[-1]
        temp = b.blobMask()
        # break everything into quintiles
        chunks = 10
        for i in range(0,chunks):
            v = temp.crop(0,temp.height*i/float(chunks),temp.width,temp.height/chunks).meanColor()[0]
            result.append(v)
        for h in b.mHu:
            result.append(h)
        result.append(b.mArea/b.mPerimeter)
        #should be minrect aspect ratio
        result.append(b.minRectWidth()/b.minRectHeight())
        
    return np.array(result)
        
truth,test = CreateDataSets(path,dirlist,split)
truth_data = None
truth_label = None
test_label = None
test_data = None

test_fname = []

for i in range(0,len(dirlist)):
    for img in truth[i]:
        img = img.scale(.3)
        r = GenerateFeatureVector(img)
        if( truth_data is None):
            truth_data = r
            truth_label = [i]
        else:
            truth_data = np.vstack((truth_data,r))
            truth_label.append(i)
        mystr = "Truth " + dirlist[i]
        img.drawText(mystr,10,10)
        img.show()
    for img in test[i]:
        test_fname.append(img.filename)
        img = img.scale(.3)
        r = GenerateFeatureVector(img)
        if( test_data is None):
            test_data = r
            test_label = [i]
        else:
            test_data = np.vstack((test_data,r))
            test_label.append(i)
        mystr = "Test " + dirlist[i]
        img.drawText(mystr,10,10)
        img.show()
print "DATA COLLECTION DONE"
print truth_data
print truth_label
#dtree = svm.SVC()
dtree = tree.DecisionTreeClassifier()#KNeighborsClassifier()
dtree.fit(truth_data,truth_label)
final = dtree.predict(test_data)
print final
test_label= np.array(test_label)        
bad = (test_label==final)
bcount = np.where(bad==False)
bad = len(bcount[0])
bins = len(dirlist)
confuse = np.zeros([bins,bins])
print "----------------------"
for i in range(0,len(final)):
    if(final[i]!=test_label[i]):
        print test_fname[i]
        myStr =  str(dirlist[test_label[i]]) + " confused as " + str(dirlist[final[i]])
        print myStr
        img = Image(test_fname[i])
        img = img.scale(.3)
        img.drawText(myStr,10,10)
        img.show()
        time.sleep(3) 

        confuse[final[i],test_label[i]]+=1

wrong = float(bad)/float(len(test_label))
correct = 100.00*(1.0-wrong)
print "We used " + str(len(truth_label)) + " training cases."
print "We got " +str(bad)+ " cases wrong."
print "With " + str(len(test_label)) + " test cases."
print "We got " + str(correct) + "% iterations correct."
print "CONFUSION MATRIX"
print "-------------------------------------------------"
print dirlist
print confuse
print "-------------------------------------------------"
print "AWESOME?!"
print "Let's make some pickles"
results = dict()
results["dtree"] = dtree
results["label_strings"] = dirlist
#oh man, this is slick
# http://stackoverflow.com/questions/1253528/is-there-an-easy-way-to-pickle-a-python-function-or-otherwise-serialize-its-cod
results["feature_extractor"] = marshal.dumps(GenerateFeatureVector.func_code)

pickle.dump(results,open("BoltTypeML.pkl","w"),pickle.HIGHEST_PROTOCOL)
