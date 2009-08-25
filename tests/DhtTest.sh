#!/bin/bash
# This is a test for the DhtHelper.py and DhtProxy.py, to have this test
# script start them, having input parameter 1 defined.  Such as
# `./DhtTest.sh test`.

key=dhttest0
value=dhttestvalue0

../scripts/DhtHelper.py register $key $value 5
../scripts/DhtHelper.py register $key"0" $value 5
../scripts/DhtHelper.py register $key"0" $value"1" 5
../scripts/DhtHelper.py register $key"1" $value 5
../scripts/DhtHelper.py register $key"1" $value"1" 5

# Test for $key

# Test0
res=`../scripts/DhtHelper.py get $key`
if [[ $res != $value ]]; then
  echo "Test 0: Failure in getting "$key" expected "$value" got "$res
fi

res=`../scripts/DhtHelper.py get $key"0"`
for i in $res; do
  if [[ $i != $value && $i != $value"1" ]]; then
    echo "Test 0a: Failure in getting "$key" expected "$value"[|1] got "$res
  fi
done

# Test1
sleep 10

res=`../scripts/DhtHelper.py get $key`
if [[ $res != $value ]]; then
  echo "Test 1: Failure in getting "$key" expected "$value" got "$res
fi

res=`../scripts/DhtHelper.py get $key"0"`
for i in $res; do
  if [[ $i != $value && $i != $value"1" ]]; then
    echo "Test 1a: Failure in getting "$key" expected "$value"[|1] got "$res
  fi
done

# Test2
res=`../scripts/DhtHelper.py dump $key`
for value in $res; do
  ../scripts/DhtHelper.py unregister $key $value
done

res=`../scripts/DhtHelper.py dump $key"0"`
for value in $res; do
  ../scripts/DhtHelper.py unregister $key"0" $value
done

sleep 10
res=`../scripts/DhtHelper.py get $key`
if [ $res ]; then
  echo "Test 2: Failure in getting "$key" expected nothing got "$res
fi

res=`../scripts/DhtHelper.py get $key"0"`
if [ $res ]; then
  echo "Test 2a: Failure in getting "$key"0 expected nothing got "$res
fi

#../scripts/DhtHelper.py dump
echo "Done with testing.  If no failure messages, tests succeeded"
