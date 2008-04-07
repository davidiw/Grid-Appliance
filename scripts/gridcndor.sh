#!/bin/bash
dir="/usr/local/ipop"
device=`cat $dir/etc/device`

configure_condor()
{
  old_ip=$2
  ipop_ns=`cat /mnt/fd/ipop_ns`
  cp $dir/etc/condor_config /etc/condor/condor_config
#  We bind to all interfaces for condor interface to work
  ip=`$dir/scripts/utils.sh get_ip $device`
  echo "NETWORK_INTERFACE = "$ip >> /etc/condor/condor_config
  $dir/scripts/sscndor.sh

  type=`cat /mnt/fd/type`
  if [ $type = "Server" ]; then
    if [ $oldip ]; then
      $dir/scripts/DhtHelper.py unregister $ipop_ns:condor:server $oldip 
    fi
    $dir/scripts/DhtHelper.py register $ipop_ns:condor:server $ip 600
    server=$ip
  else
    server=`$dir/scripts/DhtHelper.py get server $ipop_ns`
    while [ ! $server ]; do
      sleep 15
      server=`$dir/scripts/DhtHelper.py get server $ipop_ns`
    done
  fi
  flock=`$dir/scripts/DhtHelper.py get flock $ipop_ns`

  if [ $type = "Server" ]; then
    DAEMONS="MASTER, COLLECTOR, NEGOTIATOR"
  elif [ $type = "Submit" ]; then
    DAEMONS="MASTER, SCHEDD"
  elif [ $type = "Worker" ]; then
    DAEMONS="MASTER, STARTD"
  else #$type = Client
    DAEMONS="MASTER, STARTD, SCHEDD"
  fi

  echo "DAEMON_LIST = "$DAEMONS >> /etc/condor/condor_config
  echo "CONDOR_HOST = "$server >> /etc/condor/condor_config
  echo $server > $dir/var/condor_manager
  echo "FLOCK_TO = "$flock >> /etc/condor/condor_config
  echo $flock > /etc/condor/flock
}

update_flock()
{
  ipop_ns=`cat /mnt/fd/ipop_ns`
  flock=`cat /etc/condor/flock`
  new_flock=`$dir/scripts/DhtHelper.py get flock $ipop_ns`
  if [[ $flock != $new_flock ]]; then
    echo "FLOCK_TO = "$flock >> /etc/condor/condor_config
    echo $flock > /etc/condor/flock
    /opt/condor/sbin/condor_reconfig
  fi
}

if [ $1 = "start" ]; then
  configure_condor $2

  rm -f /opt/condor/var/log/* /opt/condor/var/log/*
  # This is run to limit the amount of memory condor jobs can use - up to the  contents
  # of physical memory, that means a swap disk is necessary!
  ulimit -v `cat /proc/meminfo | grep MemTotal | awk -F" " '{print $2}'`
  /opt/condor/sbin/condor_master
elif [ $1 = "restart" ]; then
  $dir/scripts/gridcndor.sh stop
  $dir/scripts/gridcndor.sh start $2
elif [ $1 = "stop" ]; then
  pkill -KILL condor
elif [ $1 = "reconfig" ]; then
  configure_condor
  /opt/condor/sbin/condor_reconfig
fi
