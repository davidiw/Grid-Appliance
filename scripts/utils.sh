#!/bin/bash
dir="/usr/local/ipop"

check_fd()
{
  return `test -f /mnt/fd/ipop_ns`
}

check_release()
{
  if [[ `cat /proc/1/environ | grep "release=yes"` != '' ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

geo_loc()
{
  iptables -F
  latitude=`wget www.ip-adress.com -q -O - | grep latitude -A 1 | grep td | awk -F">" '{print $3}' | awk -F"<" '{print $1}'`
  longitude=`wget www.ip-adress.com -q -O - | grep longitude -A 1 | grep td | awk -F">" '{print $3}' | awk -F"<" '{print $1}'`
  echo $latitude", "$longitude > /home/griduser/.geo
  $dir/scripts/iprules
}

get_ip()
{
  /sbin/ifconfig $1 | awk -F"inet addr:" '{print $2}' | awk -F" " '{print $1}'
}

get_pid()
{
  value=`ps uax | grep $1 | grep -v grep | grep -v get_pid | awk -F" " {'print $2'}` 2> /dev/null
  value=`echo $value | awk -F" " {'print $1'}`
  echo -n $value
}

get_port()
{
  value=`netstat -aup | grep $1 | awk -F":" '{print $2}' | awk -F" " '{print $1}'`
  value=`echo $value | awk -F" " {'print $1'}`
  echo -n $value
}

ping_test()
{
  ping_count=1
  ping_wait=2
  if [ -n "$2" ]; then
    ping_count=$2
    ping_wait=`expr $ping_count \* 5`
  fi
  ping -c $ping_count -w $ping_wait -i 5 $1 | grep received | awk -F", " '{print $2'} | awk -F" " '{print $1}'
}

vmm()
{
  echo `cat /proc/1/environ | tr "\0" ":" | awk -F"vmm=" '{print $2}' | awk -F":" '{print $1}'`
}

funct=$1
param0=$2
param1=$3
$funct $param0 $param1
