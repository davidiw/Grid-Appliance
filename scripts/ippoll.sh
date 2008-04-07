#!/bin/bash
#watch for new IPs and restart programs / scripts if necessary
dir="/usr/local/ipop"
device=`cat $dir/etc/device`

ip=''
if test -f $dir/var/oldip; then
  oldip=`cat $dir/var/oldip`
else
  oldip='empty'
fi

firstrun=1


while true; do
  ip=`$dir/scripts/utils.sh get_ip $device`
  while [[ $ip == '' ]]; do
    sleep 60;
    ip=`$dir/scripts/utils.sh get_ip $device`
  done

  if [[ $ip == $oldip && ! $firstrun ]]; then 
    sleep 600
  else
    echo $ip > $dir/var/oldip
    $dir/scripts/hostname.sh
    $dir/scripts/gridcndor.sh restart $oldip
    if test -f /mnt/fd/ipsec_server; then
      $dir/scripts/ipsec.py $ip $oldip
    fi
  fi
  firstrun=
  oldip=$ip
  ip=''
done
