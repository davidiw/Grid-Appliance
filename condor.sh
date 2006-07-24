#!/bin/bash

if [[ $1 = "start" ]]; then
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
