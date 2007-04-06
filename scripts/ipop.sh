#!/bin/bash
# This is the RC script for Grid-Appliance and performs the following functions
# 1) Check for a pre-existing configuration (grid_client_lastcall)
# 2a) If it does not exist, access the IPOP "DHCP" server and obtain an IP
#     address, condor configuration file, and finally generate /etc/hosts
# 2b) If it does exist, continue
# 3) Initialize the tap device
# 4) Start iprouter
# 5) Apply the iptables rules

dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`

if [[ ($1 = "stop" || $1 = "restart") && ($System = "linux" || $System = "xen0") ]]; then
  echo "Stopping Grid Services..."
  pkill -SIGINT iprouter
  sleep 10
  pkill iprouter
  if [[ $1 = "stop" ]]; then
    ifdown tap0
    $dir/tools/tunctl -d tap0
  fi
fi
if [[ $1 = "start" || $1 = "restart" ]]; then
  echo "Starting Grid Services..."

  if [[ $System = "linux" || $System = "xen0" ]]; then
    if [[ $1 = "start" ]]; then
      # set up tap device
      $dir/tools/tunctl -u root -t tap0
    fi
    if [[ $System = "xen0" ]]; then
      brctl addbr xen-ipop
      brctl addif xen-ipop tap0
      ifconfig xen-ipop up
      ifconfig tap0 up
    fi

    echo "tap configuration completed"

    # Create config file for IPOP and start it up
    if test -f $dir/var/ipop.config; then
      test
    else
      cp $dir/etc/ipop.config $dir/var/ipop.config
    fi

    cd $dir/tools
    rm -rf data
    $dir/tools/iprouter $dir/var/ipop.config 2>&1 | /usr/bin/cronolog --period="1 day" --symlink=$dir/var/ipoplog $dir/var/ipop.log.%y%m%d &
    ping -c 1 -w 1 10.191.255.254
    cd -

    ln -sf $dir/var/ipoplog /var/log/ipop
  fi

  echo "IPOP has started"
  # Applying iprules
  $dir/scripts/iprules &
  if [[ $1 = "restart" ]]; then
    ifconfig tap0 up
  fi
fi
