#!/bin/bash
source /etc/grid_appliance.config

check_release()
{
  if [[ `cat /proc/1/environ | grep "release=yes"` != "" ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

get_ipopns()
{
  source /etc/ipop.vpn.config
  grep -oE 'IpopNamespace>.*</IpopNamespace' $DIR/etc/ipop.config | grep -oE '[>][^<>]+[<]' | grep -oE '[^<>]+'
}

get_baddr()
{
  source /etc/ipop.vpn.config
  grep -z -o -E brunet:node:[a-zA-Z0-9]+ $DIR/etc/node.config
}

get_ip()
{
  res=`/sbin/ifconfig $1 | awk -F"inet addr:" {'print $2'} | awk -F" " {'print $1'} | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"`
  echo -n $res
}

get_pid()
{
  res=`ps uax | grep $1 | grep -v grep | grep -v get_pid | awk -F" " {'print $2'} | grep -oE "[0-9]+"`
  echo -n $res
}

get_port()
{
  res=`netstat -aup | grep $1 | awk -F":" {'print $2'} | grep -oE "[0-9]+"`
  echo -n $res
}

ping_test()
{
  ping_count=1
  if [ -n "$2" ]; then
    ping_count=$2
  fi
  count=0
  for (( i=0; i<$ping_count; i=$i+1 )); do
    tcount=`ping -c 1 -w 5 $1 | grep received | awk -F", " {'print $2'} | awk -F" " {'print $1'}`
    count=`expr $count + $tcount`
  done
  echo $count
}

vmm()
{
  if [[ -n `/usr/sbin/vmware-checkvm | grep good` ]]; then
    echo -n vmware
  else
    echo -n qemu
  fi
}

funct=$1
$funct ${@:2} 2> /dev/null
