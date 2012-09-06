#!/bin/bash

reset
echo "This Script Creates a python virtual environment for SimpleSeer & SimpleCV"
echo ""
echo ""
read -p "Continue [Y/n]? " -n 1
if [[ $REPLY =~ ^[Nn]$ ]]
then
		echo ""
    exit 1
fi

read -p "Install System Level Dependencies [y/N]? " -n 1
if [[ $REPLY =~ ^[Yy]$ ]]
then
		echo ""
		echo "Installing System Dependencies....."
    sudo apt-get install python-opencv python-setuptools python-pip gfortran g++ liblapack-dev libsdl1.2-dev libsmpeg-dev
fi


echo "Creating Virtual Environment"
virtualenv --distribute venv
echo "Entering Virtual Environment"
cd venv
echo "Symbolic Linking OpenCV"
ln -s /usr/local/lib/python2.7/dist-packages/cv2.so lib/python2.7/site-packages/cv2.so
ln -s /usr/local/lib/python2.7/dist-packages/cv.py lib/python2.7/site-packages/cv.py
echo "Installing dependencies"
./bin/pip install https://github.com/numpy/numpy/zipball/master
./bin/pip install https://github.com/scipy/scipy/zipball/master
./bin/pip install PIL
./bin/pip install ipython
echo "Downloading pygame"
mkdir src
wget -O src/pygame.tar.gz https://bitbucket.org/pygame/pygame/get/6625feb3fc7f.tar.gz
cd src
tar zxvf pygame.tar.gz
cd ..
echo "Running setup for pygame"
./bin/python src/pygame-pygame-6625feb3fc7f/setup.py -setuptools install
./bin/pip install https://github.com/ingenuitas/SimpleCV/zipball/master
source ./bin/activate
cd src
wget -O SimpleSeer.tar.gz https://github.com/ingenuitas/SimpleSeer/tarball/master
tar zxvf SimpleSeer.tar.gz
cd ingenuitas-SimpleSeer-*
python setup.py develop
pip install pandas
pip install -r pip.requirements
cd ../..


reset
echo "SimpleSeer should now be installed in the virtual environment"
echo "to run just type the following commands:"
echo ""
echo "simpleseer create projectname"
echo "*just press enter for all questions"
echo "cd projectname"
echo "python -m Pyro4.naming"
echo "simpleseer broker"
echo "simpleseer olap"
echo "simpleseer core"
echo "simpleseer web"
echo ""
echo "This should now start all the services in the project directory"
