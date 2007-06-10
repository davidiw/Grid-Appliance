#!/bin/bash
dir="/usr/local/ipop"

if ! `$dir/scripts/utils.sh check_fd`; then
  exit
fi

if [[ $1 = "start" ]]; then
  $dir/scripts/gridcndor.sh &
elif [[ $1 = "stop" ]]; then
  pkill -KILL gridcndor.sh
  pkill -KILL condor
elif [[ $1 = "restart" ]]; then 
  /etc/init.d/rc_cndor.sh stop
  /etc/init.d/rc_cndor.sh start
fi