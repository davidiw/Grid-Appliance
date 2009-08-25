#!/bin/bash
# This runs all the tests as necessary and places all the results into a single file

source /etc/grid_appliance.config
echo "IPOP test results..." > $dir/tests/out
$dir/tests/IPOP.sh >> $dir/tests/out
echo "Condor test results..." >> $dir/tests/out
$dir/tests/Condor.sh >> $dir/tests/out
echo "Dht test results..." >> $dir/tests/out
$dir/tests/DhtTest.sh >> $dir/tests/out
echo "Information..." >> $dir/tests/out
$dir/tests/Information.py >> $dir/tests/out
echo "ps uax" >> $dir/tests/out
ps uax >> $dir/tests/out
echo "ifconfig -a" >> $dir/tests/out
ifconfig -a >> $dir/tests/out
