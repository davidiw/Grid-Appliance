#!/bin/bash
dir="/usr/local/ipop"

connection_check_period=300

init()
{
  dev="tap0"
  #  Need ping to wait until after we wake up, duh
  ip=`$dir/scripts/utils.sh get_ip $dev`
  while [[ $ip == '' ]]; do
    sleep 60
    ip=`$dir/scripts/utils.sh get_ip $dev`
  done
}

test_manager()
{
  manager_ip=`cat $dir/var/condor_manager`
  if [[ 0 = `$dir/scripts/utils.sh ping_test $manager_ip 3 60` ]]; then
    logger -t maintenance "Unable to contact manager, restarting Condor..."
    if [ ! $dir/tests/CheckConnection.py ]; then
      $dir/scripts/gridcndor.sh reconfig
      init
      test_manager
    fi
  fi
}


while true; do
  test_manager
  sleep $connection_check_period
done
