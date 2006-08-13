#!/bin/bash
dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`

if [[ $System = "linux" || $System = "xenU" ]]; then
  if [[ $1 = "start" ]]; then
    cp $dir/config/condor_config /etc/condor/condor_config
    if [[ $System = "linux" ]]; then
      dev="tap0"
    elif [[ $System = "xenU" ]]; then
      dev="eth0"
    fi
    ip=`ifconfig $dev | awk -F"inet addr:" '{print $2}' | awk -F" " '{print $1}'`
#    manager=`echo $ip | awk -F. '{print $1"."$2"."$3"."}'`2
    manager="10.129.0.2"
    echo "CONDOR_HOST = "$manager >> /etc/condor/condor_config
    echo "NETWORK_INTERFACE = "$ip >> /etc/condor/condor_config
    echo "Starting Condor..."
    /opt/condor/sbin/condor_master
  elif [ $1 = "stop" ]; then
    echo "Stopping Condor..."
    pkill -KILL condor
  elif [ $1 = "restart" ]; then
    echo "Restarting Condor..."
    /etc/init.d/gridcndor.sh stop
    /etc/init.d/gridcndor.sh start
  else
    echo "Run script with start, restart, or stop"
  fi
fi
