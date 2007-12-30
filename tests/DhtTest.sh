#!/bin/bash
# This is a test for the DhtHelper.py and DhtProxy.py, to have this test
# script start them, having input parameter 1 defined.  Such as
# `./DhtTest.sh test`.

if [ $1 ]; then
  ../scripts/DhtProxy.py &
  pid=$!
fi
key=dhttest0
value=dhttestvalue0

../scripts/DhtHelper.py register $key $value 5
../scripts/DhtHelper.py register $key"0" $value 5
../scripts/DhtHelper.py register $key"0" $value"1" 5
../scripts/DhtHelper.py register $key"1" $value 5
../scripts/DhtHelper.py register $key"1" $value"1" 5
res=`../scripts/DhtHelper.py get $key`
if [ $res != $value ]; then
  echo "Test 0: Failure in getting "$key" expected "$value" got "$res
fi
sleep 10
res=`../scripts/DhtHelper.py get $key`
if [ $res != $value ]; then
  echo "Test 1: Failure in getting "$key" expected "$value" got "$res
fi
../scripts/DhtHelper.py unregister $key $value
sleep 10
res=`../scripts/DhtHelper.py get $key`
if [ $res ]; then
  echo "Test 1: Failure in getting "$key" expected nothing got "$res
fi
../scripts/DhtHelper.py dump
echo "Done with testing.  If no failure messages, tests succeeded"

if [ $pid ]; then
  kill -KILL $pid
fi