#!/bin/bash
# This runs all the tests as necessary and places all the results into a single file

dir="/usr/local/ipop"
echo "IPOP test results..." > $dir/tests/out
$dir/tests/IPOP.sh >> $dir/tests/out
echo "Condor test results..." >> $dir/tests/out
$dir/tests/Condor.sh >> $dir/tests/out
echo "Dht test results..." >> $dir/tests/out
$dir/tests/DhtTest.sh >> $dir/tests/out