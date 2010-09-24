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
  /sbin/ifconfig $1 | awk -F"inet addr:" {'print $2'} | awk -F" " {'print $1'} | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"
}

get_netmask()
{
  /sbin/ifconfig $1 | awk -F"Mask:" {'print $2'} | awk -F" " {'print $1'} | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"
}

get_pid()
{
  ps uax | grep $1 | grep -v grep | grep -v get_pid | awk -F" " {'print $2'} | grep -oE "[0-9]+"
}

get_port()
{
  netstat -aup | grep $1 | awk -F":" {'print $2'} | grep -oE "[0-9]+"
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

get_cidr()
{
  ip=$(get_ip $1)
  mask=$(get_netmask $1)
  if [[ $ip == "" || $mask == "" ]]; then
    return
  fi

  ipa=($(echo $ip | sed 's/\./ /g'))
  maska=($(echo $mask | sed 's/\./ /g'))

  cidr=$((${ipa[0]} & ${maska[0]}))
  cidr=$cidr.$((${ipa[1]} & ${maska[1]}))
  cidr=$cidr.$((${ipa[2]} & ${maska[2]}))
  cidr=$cidr.$((${ipa[3]} & ${maska[3]}))
  cidr=$cidr/$(mask2cidr $mask)
  echo -n $cidr
}

mask2cidr()
{
  nbits=0
  IFS=.
  for dec in $1 ; do
    case $dec in
      255) let nbits+=8;;
      254) let nbits+=7;;
      252) let nbits+=6;;
      248) let nbits+=5;;
      240) let nbits+=4;;
      224) let nbits+=3;;
      192) let nbits+=2;;
      128) let nbits+=1;;
      0);;
      *) echo "Error: $dec is not recognised"; exit 1
    esac
  done
  echo -n "$nbits"
}

funct=$1
$funct ${@:2} 2> /dev/null
