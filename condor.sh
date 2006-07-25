#!/bin/bash

if [[ $1 = "start" ]]; then
  cp /root/client/condor_config /home/condor/condor/etc/condor_config
  ip=`ifconfig eth0 | awk -F"inet addr:" '{print $2}' | awk -F" " '{print $1}'`
  manager=`echo $ip | awk -F. '{print $1"."$2"."$3"."}'`2
  echo $ip >> /home/condor/condor/etc/condor_config
  echo $manger >> /home/condor/condor/etc/condor_config
  echo "Starting Condor..."
  /home/condor/condor/sbin/condor_master
elif [ $1 = "stop" ]; then
  echo "Stopping Condor..."
  pkill -KILL condor_*
elif [ $1 = "restart" ]; then
  echo "Restarting Condor..."
  /etc/init.d/condor stop
  /etc/init.d/condor start
else
  echo "Run script with start, restart, or stop"
fi
