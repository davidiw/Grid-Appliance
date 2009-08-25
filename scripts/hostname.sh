#!/bin/bash
source /etc/ipop.vpn.config
source /etc/grid_appliance.config

ip=`$DIR/scripts/utils.sh get_ip $DEVICE`
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
