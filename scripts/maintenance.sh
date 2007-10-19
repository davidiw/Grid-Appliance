#!/bin/bash
#broken for now
exit
dir="/usr/local/ipop"

backoff=1
basetime=120
backoffmax=256
backoffmin=1

init()
{
  dev="tap0"
  #  Need ping to wait until after we wake up, duh
  ip=`$dir/scripts/utils.sh get_ip $dev`
  while [[ $ip == '' ]]; do
    sleep 60
    ip=`$dir/scripts/utils.sh get_ip $dev`
    if [[ `$dir/scripts/utils.sh get_pid IPRouter` = '' ]]; then
      $dir/scripts/ipop.sh restart quiet
    fi
  done
  sleep $[$basetime*$backoff]
  backoff=$[2*$backoff]
  if [[ $backoff > $backoffmax ]]; then
    backoff=$backoffmax;
  fi
}

test_manager()
{
  restart=false
  manager_ip=`cat $dir/var/condor_manager`
  if [[ `$dir/scripts/utils.sh get_pid IPRouter` = '' ]]; then
    restart=true
  elif [[ 0 = `$dir/scripts/utils.sh ping_test $manager_ip 24` ]]; then
    restart=true
  fi

  if [[ $restart == "true" ]]; then
    logger -t maintenance "Unable to contact manager, restarting Condor..."
    $dir/scripts/gridcndor.sh restart
    init
    test_manager
  fi
}


if [[ $1 = start ]]; then
  init
  test_manager
fi

while true; do
  test_manager
  sleep $[$basetime*$backoff]
  if [[ $backoff > $backoffmin ]]; then
    backoff=$[$backoff/2]
  fi
done
