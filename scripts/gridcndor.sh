#!/bin/bash
dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`

if [[ $System = "linux" || $System = "xenU" ]]; then
  ip=''
  oldip=''

  if [[ $System = "linux" ]]; then
    dev="tap0"
  elif [[ $System = "xenU" ]]; then
    dev="eth0"
  fi

  while true; do
    ip=`ifconfig $dev | awk -F"inet addr:" '{print $2}' | awk -F" " '{print $1}'`
    while [[ $ip == '' ]]; do
      sleep 60;
      ip=`ifconfig $dev | awk -F"inet addr:" '{print $2}' | awk -F" " '{print $1}'`
    done

    if [[ $ip == $oldip ]]; then 
      sleep 600
    else
      pkill -KILL condor
      # Geo locator
      iptables -F
      latitude=`wget www.ip-adress.com -q -O - | grep latitude -A 1 | grep td | awk -F">" '{print $3}' | awk -F"<" '{print $1}'`
      longitude=`wget www.ip-adress.com -q -O - | grep longitude -A 1 | grep td | awk -F">" '{print $3}' | awk -F"<" '{print $1}'`
      echo $latitude", "$longitude > /home/griduser/.geo
      $dir/scripts/iprules
      cp $dir/etc/condor_config /etc/condor/condor_config
      manager="10.128.0.1"
      echo "CONDOR_HOST = "$manager >> /etc/condor/condor_config
      echo "NETWORK_INTERFACE = "$ip >> /etc/condor/condor_config
      GEO_LOC=`cat /home/griduser/.geo`
      echo "GEO_LOC = \"$GEO_LOC\"" >> /etc/condor/condor_config
      echo "STARTD_EXPRS = STARTD_EXPRS, GEO_LOC" >> /etc/condor/condor_config

      if test -f /usr/local/ipop/etc/manager; then
        echo "DAEMON_LIST                     = MASTER, COLLECTOR, NEGOTIATOR" >> /etc/condor/condor_config
      elif test -f /usr/local/ipop/etc/watcher; then
        echo "DAEMON_LIST                     = MASTER, SCHEDD" >> /etc/condor/condor_config
      else
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

# This is run to limit the amount of memory condor jobs can use - up to the  contents
# of physical memory, that means a swap disk is necessary!
      ulimit -v `cat /proc/meminfo | grep MemTotal | awk -F" " '{print $2}'`
      /opt/condor/sbin/condor_master
    fi
    oldip=$ip
    ip=''
  done
fi
