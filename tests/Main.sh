#!/bin/bash
# This runs all the tests as necessary and places all the results into a single file

source /etc/grid_appliance.config
echo "IPOP test results..." > $DIR/tests/out
$DIR/tests/IPOP.sh >> $DIR/tests/out
echo "Condor test results..." >> $DIR/tests/out
$DIR/tests/Condor.sh >> $DIR/tests/out
echo "Dht test results..." >> $DIR/tests/out
$DIR/tests/DhtTest.sh >> $DIR/tests/out
echo "Information..." >> $DIR/tests/out
$DIR/tests/Information.py >> $DIR/tests/out
echo "CONDOR_HOST..." >> $DIR/tests/out
config=$DIR"/etc/condor_config.d/00root"
res=`grep CONDOR_HOST $config | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"`
if [[ "$res" ]]; then
  $DIR/tests/RemotePeer.py >> $DIR/tests/out
fi
echo "ps uax" >> $DIR/tests/out
ps uax >> $DIR/tests/out
echo "ifconfig -a" >> $DIR/tests/out
ifconfig -a >> $DIR/tests/out
