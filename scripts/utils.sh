#!/bin/bash
dir="/usr/local/ipop"

check_fd()
{
  return `test -f /mnt/fd/ipop_ns`
}

check_release()
{
  if [[ `cat /proc/1/environ | grep "release=yes"` != "" ]]; then
    echo "yes"
  else
    echo "no"
  fi
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
  echo `cat /proc/1/environ | tr "\0" ":" | awk -F"vmm=" {'print $2'} | awk -F":" {'print $1'}`
}

funct=$1
$funct ${@:2} 2> /dev/null
