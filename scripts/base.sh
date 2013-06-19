# To be ran from within a project
echo "--------------------------------------------------------"
echo "- Installing SimpleSeer                                -"
echo "--------------------------------------------------------"
cd SimpleSeer
python setup.py develop
cd ..
if [ -d SeerCloud ]
  then
    echo "--------------------------------------------------------"
    echo "- Installing SeerCloud                                 -"
    echo "--------------------------------------------------------"
    cd SeerCloud
    python setup.py develop
fi