#!/bin/bash
dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`

if [[ $System = "linux" || $System = "xenU" ]]; then
  if [[ $1 = "start" ]]; then
    $dir/scripts/gridcndor.sh &
  elif [[ $1 = "stop" ]]; then
    pkill -KILL gridcndor.sh
    pkill -KILL condor
  elif [[ $1 = "restart" ]]; then 
    /etc/init.d/rc_cndor.sh stop
    /etc/init.d/rc_cndor.sh start
  fi
fi
