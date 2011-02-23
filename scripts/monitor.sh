#!/bin/bash
# Monitor the state of our features (Brunet, IPOP, and Condor)
source /etc/ipop.vpn.config
IDIR=$DIR
source /etc/grid_appliance.config

statefd=$DIR"/var/monitor.state"

ip_start=true
condor_break=

# This is used to determine if we are still connected to the condor manager
# and will help find a new one if we are no longer able to connect to him
condor_control()
{
  condor_break=true
# Are we connected?
  if [[ "$($DIR/tests/CheckConnection.py)" != "True" ]]; then
    return
# Is condor running?
  elif [[ ! "$($DIR/scripts/utils.sh get_pid condor_master)" ]]; then
    logger -t maintenance "Condor is off, starting Condor..."
    $DIR/scripts/condor.sh restart
    return
# Did we just restart ipop?
  elif [[ $ip_start ]]; then
    logger -t maintenance "Reconfiguring Condor..."
    $DIR/scripts/condor.sh reconfig
    return
  fi

  manager_ip=$(cat $DIR/var/condor_manager)
# Is the manager_ip set, does it match what condor is using?
  if [[ "$manager_ip" != "$(condor_config_val CONDOR_HOST)" ]]; then
    logger -t maintenance "Condor is missing the manager_ip... reconfiguring condor"
    $DIR/scripts/condor.sh reconfig
    return
# Send some pings to the manager, see if he is operational
  elif [[ $($DIR/scripts/utils.sh ping_test $manager_ip 3 60) == 0 ]]; then
    logger -t maintenance "Unable to contact manager, reconfiguring Condor..."
    $DIR/scripts/condor.sh reconfig
    return
  fi

  condor_break=
}

restart_ipop()
{
# Now in some bizarre undiagnosed cases, the config files are broken, this is
# not an easily recoverable or detectable error, so this checks the configs
# if this fails, re-run groupvpn_prepare.sh...
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
}

configure_networking()
{
  $DIR/scripts/utils.sh set_hostname
  # Unable to resolve DNS, something weird is happening
  hostname -f >&- 2>&- <&-
  if [[ $? == 1 ]]; then
    ip_start=true
    hostname=localhost
    return
  fi
  ip_start=
}

check()
{
# step 0 - check if Ipop is working!
  if [[ `$DIR/tests/CheckSelf.py` == "False" ]]; then
    restart_ipop
    return
  fi

# step 1 - wait for an IP before proceeding
  ip=`$DIR/scripts/utils.sh get_ip $DEVICE`
  if [[ ! $ip ]]; then
    return
  fi

# step 2 - We just got an IP, configure networking
  if [[ $ip_start ]]; then
    configure_networking
  fi
  
# step 3 - Networking complete, let's work on Condor!
  condor_control
}

while true; do
  check
# If there is a failure in condor (unable to communicate to manager) or we
# haven't been allocated an IP yet, let's begin to loop faster.
  if [[ $ip_start  || $condor_break ]]; then
    if [[ $ip_start ]]; then
      echo "ip_start" > $statefd
    elif [[ $condor_break ]]; then
      echo "condor_break" > $statefd
    fi
    sleep 30
  else
    echo "good" > $statefd
    $IDIR/bin/dump_dht_proxy.py $IDIR/etc/dht_proxy
    sleep 600
  fi
done
