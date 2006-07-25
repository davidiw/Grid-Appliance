#!/bin/bash
# This is the RC script for Grid-Appliance and performs the following functions
# 1) Check for a pre-existing configuration (grid_client_lastcall)
# 2a) If it does not exist, access the IPOP "DHCP" server and obtain an IP
#     address, condor configuration file, and finally generate /etc/hosts
# 2b) If it does exist, continue
# 3) Initialize the tap device
# 4) Start iprouter
# 5) Apply the iptables rules

if [[ $1 = "start" || $1 = "restart" ]]; then
  iptables -F
  if [[ $1 = start ]]; then
    echo "Resuming a previous Grid machine..."
  else
    echo "Restarting Grid services..."
    pkill iprouter 
  fi

  # set up tap device and routes
  ifconfig tap0 down
  /root/tools/tunctl -u root -t tap0

  echo "tap configuration completed"

  # Create config file for IPOP and start it up
  /bin/cp /root/client/ipop.config /root/client/var/ipop.config
  /root/tools/iprouter /root/client/var/ipop.config &> /root/client/var/ipoplog &

  echo "IPOP has started"

  # Applying iprules
  /root/client/iprules

  # Link to the new log
  /bin/ln -s /root/client/var/ipoplog /var/log/ipop
elif [ $1 = "stop" ]; then
  pkill iprouter
  ifdown tap0
  /root/tools/tunctl -d tap0
else
  echo "Run script with start, restart, or stop"
fi
