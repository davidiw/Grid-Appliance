#!/bin/bash

if [[ $1 = "start" ]]; then
  cp /root/client/config/condor_config /home/condor/condor_config
  ip=`ifconfig tap0 | awk -F"inet addr:" '{print $2}' | awk -F" " '{print $1}'`
  manager=`echo $ip | awk -F. '{print $1"."$2"."$3"."}'`2
  echo "CONDOR_HOST = "$manager >> /home/condor/condor_config
  echo "NETWORK_INTERFACE = "$ip >> /home/condor/condor_config
  echo "Starting Condor..."
  /home/condor/condor/sbin/condor_master
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
