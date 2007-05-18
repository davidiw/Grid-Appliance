#!/bin/bash
if [[ $1 = start ]]; then
#  Need ping to wait until after we wake up, duh
  ip=`ifconfig $dev | awk -F"inet addr:" '{print $2}' | awk -F" " '{print $1}'`
  while [[ $ip == '' ]]; do
    sleep 60;
    ip=`ifconfig $dev | awk -F"inet addr:" '{print $2}' | awk -F" " '{print $1}'`
  done
  ping -c 1 -w 1 10.191.255.254
fi

