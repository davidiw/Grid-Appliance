#!/bin/bash
dir="/usr/local/ipop"

ip=''
oldip=''

dev="tap0"

while true; do
  ip=`$dir/scripts/utils.sh get_ip $dev`
  while [[ $ip == '' ]]; do
    sleep 60;
    ip=`$dir/scripts/utils.sh get_ip $dev`
  done

  if [[ $ip == $oldip ]]; then 
    sleep 600
  else
    pkill -KILL condor
    # Geo locator
    $dir/scripts/utils.sh geo_loc

    cp $dir/etc/condor_config /etc/condor/condor_config
    if test ! -f $dir/etc/condor_manager; then
      cp /mnt/fd/condor_manager $dir/etc/condor_manager
    fi
    manager=`cat $dir/etc/condor_manager`
    echo "CONDOR_HOST = "$manager >> /etc/condor/condor_config
#  We bind to all interfaces for condor interface to work
    echo "NETWORK_INTERFACE = "$ip >> /etc/condor/condor_config
    GEO_LOC=`cat /home/griduser/.geo`
    echo "GEO_LOC = \"$GEO_LOC\"" >> /etc/condor/condor_config
    echo "STARTD_EXPRS = STARTD_EXPRS, GEO_LOC" >> /etc/condor/condor_config
    $dir/scripts/sscndor.sh

    if test ! -f $dir/etc/condor_type; then
      echo "standard" >> $dir/etc/condor_type
    fi

    type=`cat $dir/etc/condor_type`
    if [ $type = "manager" ]; then
      echo "DAEMON_LIST                     = MASTER, COLLECTOR, NEGOTIATOR" >> /etc/condor/condor_config
    elif [ $type = "submit" ]; then
      echo "DAEMON_LIST                     = MASTER, SCHEDD" >> /etc/condor/condor_config
    else # [ $type = "standard" || undefined ]
      echo "DAEMON_LIST                     = MASTER, STARTD, SCHEDD" >> /etc/condor/condor_config
    fi

    hostname="C"
    for (( i = 2; i < 5; i++ )); do
      temp=`echo $ip | awk -F"." '{print $'$i'}' | awk -F"." '{print $1}'`
      if (( $temp < 10 )); then
        hostname=$hostname"00"
      elif (( $temp < 100 )); then
        hostname=$hostname"0"
      fi
      hostname=$hostname$temp
    done
    hostname $hostname

    rm -f /opt/condor/var/log/* /opt/condor/var/log/*
# This is run to limit the amount of memory condor jobs can use - up to the  contents
# of physical memory, that means a swap disk is necessary!
    ulimit -v `cat /proc/meminfo | grep MemTotal | awk -F" " '{print $2}'`
    /opt/condor/sbin/condor_master
  fi
  oldip=$ip
  ip=''
done
