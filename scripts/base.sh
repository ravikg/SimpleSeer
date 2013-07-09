# To be ran from within a project
echo "--------------------------------------------------------"
echo "- Installing SimpleSeer                                -"
echo "--------------------------------------------------------"
git submodule update
cd SimpleSeer
sudo python setup.py develop
cd ..
if [ -d SeerCloud ]
  then
    echo "--------------------------------------------------------"
    echo "- Installing SeerCloud                                 -"
    echo "--------------------------------------------------------"
    cd SeerCloud
    python setup.py develop
fi