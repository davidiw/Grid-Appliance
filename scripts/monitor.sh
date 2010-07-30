#!/bin/bash
# Monitor the state of our features (Brunet, IPOP, and Condor)
source /etc/ipop.vpn.config
IDIR=$DIR
source /etc/grid_appliance.config

statefd=$DIR"/var/monitor.state"

ip=
old_ip=
if test -f $DIR/var/oldip; then
  old_ip=`cat $DIR/var/oldip`
fi

ip_start=true
condor_break=

# This is used to determine if we are still connected to the condor manager
# and will help find a new one if we are no longer able to connect to him
condor_control()
{
  condor_break=true
# Are we connected, is gridcndor running?  let's come back soon...
  if [[ `$DIR/tests/CheckConnection.py` != "True" || "`$DIR/scripts/utils.sh get_pid condor.sh`" ]]; then
    return
  elif [[ ! "`$DIR/scripts/utils.sh get_pid condor`" ]]; then
    $DIR/scripts/condor.sh restart | logger -t maintenance &
    return
  fi

  manager_ip=`cat $DIR/var/condor_manager`
# Send some pings to the manager, see if he is operational
  if [[ "$manager_ip" && 0 == `$DIR/scripts/utils.sh ping_test $manager_ip 3 60` ]]; then
    logger -t maintenance "Unable to contact manager, restarting Condor..."
    $DIR/scripts/condor.sh reconfig | logger -t maintenance &
    return
  fi

  condor_break=
}

# This handles condor control loop and other features that rely on IP
ip_control()
{
# step 0 - check if Ipop is working!
  if [[ `$DIR/tests/CheckSelf.py` == "False" ]]; then
# Now in some bizarre undiagnosed cases, some of the config files are broken,
# this is not an easily recoverable or detectable error, so this checks the configs
# if one is bad, re-run groupvpn_prepare.sh...
    for file in ipop.config node.config bootstrap.config dhcp.config; do
      python $DIR/scripts/xml-check.py $IDIR/etc/$file
      if [[ $? != 0 ]]; then
        groupvpn_prepare.sh $DIR/var/groupvpn.zip
        break
      fi
    done
    /etc/init.d/groupvpn.sh stop
# if we don't have a working hostname, things break, if we don't have an IP
# address that resolves properly, then other things begin to break
    hostname localhost
    resolvconf -u
    /etc/init.d/groupvpn.sh start
    ip_start=true
  fi

# step 1 - determine if we should proceed
  ip=`$DIR/scripts/utils.sh get_ip $DEVICE`
  if [[ ! $ip ]]; then
    return
  fi

# step 2 - We have an IP, let's check condor
  condor_control

# step 3 - if no change in ip, quit if this isn't our first run
  if [[ ! $ip_start && $old_ip == $ip ]]; then
    return
  fi

# step 4 - if we have a change in ip, update oldip config and update ipsec,
# if necessary
  if [[ $old_ip != $ip ]]; then
    old_ip=$ip
    echo $ip > $DIR/var/oldip
  fi

# step 5 - clear ip_start, set our hostname, and (re)start condor
  $DIR/scripts/hostname.sh
  hostname -f >&- 2>&- <&-
  if [[ $? == 1 ]]; then
    ip_start=true
    hostname=localhost
    return
  fi
  ip_start=
  $DIR/scripts/condor.sh restart
  condor_break=true
}

while true; do
  ip_control
# If there is a failure in condor (unable to communicate to manager) or we
# haven't been allocated an IP yet, let's begin to loop faster.
  if [[ $ip_start || $baddr_start || $condor_break ]]; then
    if [[ $ip_start ]]; then
      echo "ip_start" > $statefd
    elif [[ $condor_break ]]; then
      echo "condor_break" > $statefd
    fi
    sleep 60
  else
    echo "good" > $statefd
    sleep 600
  fi
done
