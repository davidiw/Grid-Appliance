#!/bin/bash
dir="/usr/local/ipop"

init()
{
  dev="tap0"
  #  Need ping to wait until after we wake up, duh
  ip=`$dir/scripts/utils.sh get_ip $dev`
  while [[ $ip == '' ]]; do
    sleep 60;
    ip=`$dir/scripts/utils.sh get_ip $dev`
  done
  test_manager
}

test_manager()
{
  manager_ip=`cat $dir/etc/condor_manager`
  if [[ 0 = `$dir/scripts/utils.sh ping_test $manager_ip 12` ]]; then
    $dir/scripts/ipop.sh restart
    init
  fi
}


if [[ $1 = start ]]; then
  init
fi

while true; do
  test_manager
  sleep 7200
done
