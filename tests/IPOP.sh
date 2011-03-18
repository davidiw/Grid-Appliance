#!/bin/bash
# Used to test if ipop is properly configured in the appliance

source /etc/ipop.vpn.config
if [[ ! -e $DIR"/etc/ipop.config" ]]; then
  echo "ipop.config missing!"
  exit
fi

source /etc/grid_appliance.config

if [[ -z $($DIR/scripts/utils.sh get_pid Ipop) ]]; then
  echo "IPOP isn't running!"
fi

if [[ -z $($DIR/scripts/utils.sh get_pid dhclient.tapipop) ]]; then
  echo "Dhcp services for tap0 aren't running."
fi

if [[ -z $($DIR/scripts/utils.sh get_ip tapipop) ]]; then
  echo "tap0 has no ip address."
fi

ipop_ns=$($DIR/scripts/utils.sh get_ipopns)
if [[ -z $($DIR/scripts/DhtHelper.py get dhcp:ipop_namespace:$ipop_ns) ]]; then
  echo "Dht operations failed."
fi

if [[ $($DIR/scripts/utils.py check_self) == "False" ]]; then
  echo "IPOP not responding."
fi

if [[ $($DIR/scripts/utils.py check_connections) == "False" ]]; then
  echo "IPOP not connected."
fi

if [[ $($DIR/src/utils.py check_ip) == "False" ]]; then
  echo "IPOP IP missing from DHT."
fi
