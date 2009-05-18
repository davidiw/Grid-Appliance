#!/bin/bash
dir="/usr/local/ipop"
config=$dir"/etc/condor_config.d/00root"
device=`cat $dir/etc/device`

configure_condor()
{
  ipop_ns=`cat /mnt/fd/ipop_ns`
#  We bind to all interfaces for condor interface to work
  ip=`$dir/scripts/utils.sh get_ip $device`
  echo "NETWORK_INTERFACE = "$ip > $config

  type=`cat /mnt/fd/type`
  if [ $type = "Server" ]; then
    registered=`$dir/scripts/DhtHelper.py dump $ipop_ns:condor:server`
    for reg in $registered; do
      $dir/scripts/DhtHelper.py unregister $ipop_ns:condor:server $reg
    done
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

  echo "DAEMON_LIST = "$DAEMONS >> $config
  echo "CONDOR_HOST = "$server >> $config
  echo $server > $dir/var/condor_manager
  echo "FLOCK_TO = "$flock >> $config
  echo $flock > $dir/var/condor_flock

  if test -e /mnt/fd/condor_group; then
    echo "Group = \"`cat /mnt/fd/condor_group`\"" >> $config
    echo "STARTD_ATTRS = \$(STARTD_ATTRS), Group" >> $config
    echo "RANK = TARGET.Group =?= MY.Group" >> $config
    echo "SUBMIT_EXPRS = \$(SUBMIT_EXPRS), Group" >> $config
    if [ $type = "Server" ]; then
      echo "NEGOTIATOR_PRE_JOB_RANK = 10 * (MY.RANK) + 1 * (RemoteOwner =?= UNDEFINED)" >> $config
    fi
  fi

  if test -e /mnt/fd/condor_user; then
    user=`cat /mnt/fd/condor_user`
  elif test -e /mnt/fd/user_config; then
    user=`grep  -E 'O=\S*' /mnt/fd/user_config  | awk -F"=" '{print $2}'`
  fi

  if [ "$user" ]; then
    echo "User = $user" >> $config
    echo "STARTD_ATTRS = \$(STARTD_ATTRS), User" >> $config
    echo "SUBMIT_EXPRS = \$(SUBMIT_EXPRS), User" >> $config
  fi
}

update_flock()
{
  ipop_ns=`cat /mnt/fd/ipop_ns`
  flock=`cat /etc/condor/flock`
  new_flock=`$dir/scripts/DhtHelper.py get flock $ipop_ns`
  if [[ $flock != $new_flock ]]; then
    echo "FLOCK_TO = "$flock >> $config
    echo $flock > $dir/var/condor_flock
    /opt/condor/sbin/condor_reconfig
  fi
}

if [ $1 = "start" ]; then
  configure_condor
  rm -f /opt/condor/var/log/* /opt/condor/var/log/*
  # This is run to limit the amount of memory condor jobs can use - up to the  contents
  # of physical memory, that means a swap disk is necessary!
  ulimit -v `cat /proc/meminfo | grep MemTotal | awk -F" " '{print $2}'`
  /opt/condor/sbin/condor_master
elif [ $1 = "restart" ]; then
  $dir/scripts/gridcndor.sh stop
  $dir/scripts/gridcndor.sh start
elif [ $1 = "stop" ]; then
  pkill -KILL condor
elif [ $1 = "reconfig" ]; then
  configure_condor
  /opt/condor/sbin/condor_reconfig
fi
