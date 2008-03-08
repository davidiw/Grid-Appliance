#!/bin/bash
# Used to test if ipop is properly configured in the appliance

config="/usr/local/ipop/var/ipop.config"
dir="/usr/local/ipop"
if [ ! -e $config ]; then
  echo "ipop.config missing!"
  exit
fi

floppy_contents=(ipop_ns type ipop.config dhcpdata.conf user_config)
for flc in $floppy_contents; do
  fail=0
  if [ ! -e /mnt/fd/$flc ]; then
    fail=1
    echo "Floppy missing "$flc"."
  fi
  if [ $fail = 1 ]; then
    exit
  fi
done

res=`grep ipop_namespace $config | awk -F ">" {'print $2'} | awk -F "<" {'print $1'}`
if [ "$res" != "`cat /mnt/fd/ipop_ns`" ]; then
  echo "Namespace error: "$res" != "`cat /mnt/fd/ipop_ns`"!"
fi

if [ -z `$dir/scripts/utils.sh get_pid IPRouter` ]; then
  echo "IPRouter isn't running!"
fi

if [ -z `$dir/scripts/utils.sh get_pid dhclient.tap0` ]; then
  echo "Dhcp services for tap0 aren't running."
fi

if [ -z `$dir/scripts/utils.sh get_ip tap0` ]; then
  echo "tap0 has no ip address."
fi

if [ -z "$($dir/scripts/DhtHelper.py get dhcp:ipop_namespace:$(cat /mnt/fd/ipop_ns))" ]; then
  echo "Dht operations failed."
fi

if [ `$dir/tests/CheckSelf.py` = "False" ]; then
  echo "IPOP not responding."
fi

if [ `$dir/tests/CheckConnection.py` = "False" ]; then
  echo "IPOP not connected."
fi
