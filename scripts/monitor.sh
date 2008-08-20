#!/bin/bash
# Monitor the state of our features (Brunet, IPOP, and Condor)
dir="/usr/local/ipop"
device=`cat $dir/etc/device`

ip=
old_ip=
if test -f $dir/var/oldip; then
  old_ip=`cat $dir/var/oldip`
fi

baddr=
old_baddr=
if test -f $dir/var/oldbaddr; then
  old_baddr=`cat $dir/var/oldbaddr`
fi

ip_start=true
baddr_start=true
condor_break=

# this has a lot of logic for future operations, but currently it is only used
# to determine whether or not we should check the ipopsec info to see if it is
# up to date and accurate
baddr_control()
{
# step 1 - determine if we should proceed
  baddr=`$dir/scripts/utils.sh get_baddr`
  if [[ ! $baddr && (! $baddr_start || $old_baddr == $baddr) ]]; then
    return
  fi

# step 2 - determine if there was a change in baddr
  if [[ $old_baddr != $baddr ]]; then
    echo $baddr > $dir/var/oldbaddr
    old_baddr=baddr
# step 3 - if no change in baddr, quit if this isn't our first run
  elif [[ ! $baddr_start ]]; then
    return
  fi
  baddr_start=

# step 4 - check and update certificate if necessary
  if test -f /mnt/fd/ipopsec_server; then
    makecert=true
    if test -f $dir/tools/certificates/lc.cert; then
      cd $dir/tools
      certout=`mono certhelper.exe readcert cert=$dir/tools/certificates/lc.cert`
      certaddr=`echo $certout | grep -z -o -E brunet:node:[a-zA-Z0-9]+`
      if [[ $certaddr == $baddr ]]; then
        makecert=
      fi
      cd - &> /dev/null
    fi

    if [[ $makecert ]]; then
      $dir/scripts/ipopsec.py $baddr
    fi
  fi
}

# This is used to determine if we are still connected to the condor manager
# and will help find a new one if we are no longer able to connect to him
condor_control()
{
  condor_break=
  manager_ip=`cat $dir/var/condor_manager`

# Send some pings to the manager, see if he is operational
  if [[ 0 == `$dir/scripts/utils.sh ping_test $manager_ip 3 60` ]]; then
# No ping responses, so let's make sure we are connected
    if [[ `$dir/tests/CheckConnection.py` == "True" ]]; then
# We are connected but no response from manager, let's reconfig
      logger -t maintenance "Unable to contact manager, restarting Condor..."
      $dir/scripts/gridcndor.sh reconfig | logger -t maintenance
      condor_break=true
    fi
  fi
}

# This handles condor control loop and other features that rely on IP such as
# hostname and ipsec
ip_control()
{
# step 0 - check if Ipop is working!
  if [[ `$dir/tests/CheckSelf.py` == "False" ]]; then
    /etc/init.d/ipop.sh restart
  fi
# step 1 - determine if we should proceed
  ip=`$dir/scripts/utils.sh get_ip $device`
  if [[ ! $ip ]]; then
# if we don't have a working hostname, things break, if we don't have an IP
# address that resolves properly, then other things begin to break
    hostname localhost
    return
  fi

# step 2 -We have an IP, let's check condor
  condor_control

# step 3 - if no change in ip, quit if this isn't our first run
  if [[ ! $ip_start && $old_ip == $ip ]]; then
    return
  fi

# step 4 - if we have a change in ip, update oldip config and update ipsec,
# if necessary
  if [[ $old_ip != $ip ]]; then
    old_ip=$ip
    echo $ip > $dir/var/oldip
    if test -f /mnt/fd/ipsec_server; then
      $dir/scripts/ipsec.py $ip $old_ip
    fi
  fi

# step 5 - clear ip_start, set our hostname, and (re)start condor
  ip_start=
  $dir/scripts/hostname.sh
  $dir/scripts/gridcndor.sh restart $old_ip
}

while true; do
  baddr_control
  ip_control
# If there is a failure in condor (unable to communicate to manager) or we
# haven't been allocated an IP yet, let's begin to loop faster.
  if [[ $ip_start || $baddr_start || $condor_break ]]; then
    sleep 60
  else
    sleep 600
  fi
done
