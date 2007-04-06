#!/bin/bash
# Geo locator

dir="/usr/local/ipop"

if [[ $1 == "start" ]]; then
  iptables -F
  latitude=`wget www.ip-adress.com -q -O - | grep latitude -A 1 | grep td | awk -F">" '{print $3}' | awk -F"<" '{print $1}'`
  longitude=`wget www.ip-adress.com -q -O - | grep longitude -A 1 | grep td | awk -F">" '{print $3}' | awk -F"<" '{print $1}'`
  echo $latitude", "$longitude > /home/griduser/.geo
  $dir/scripts/iprules
fi
