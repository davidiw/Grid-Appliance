#!/bin/bash

### BEGIN INIT INFO
# Provides:          grid_appliance_static
# Required-Start:    $local_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Begins Grid Appliance config and IPOP
# Description:       Enable Grid Appliance, Condor, IPOP
### END INIT INFO

source /etc/grid_appliance.config
device="tun0"
server="10.8.0.1"
daemons="MASTER, STARTD"
config=$DIR"/etc/condor_config.d/00root"

function start() {
  ip=$($DIR/scripts/utils.sh get_ip eth0)
  while [[ ! $ip ]]; do
    ip=$($DIR/scripts/utils.sh get_ip eth0)
    sleep 1
  done

  if [[ ! -e /dev/net/tun ]]; then
    mkdir /dev/net
    mknod /dev/net/tun c 10 200
    chmod 666 /dev/net/tun
  fi

  openvpn --config /opt/openvpn/client.conf &> /opt/openvpn/log < /dev/null &

  ip=$($DIR/scripts/utils.sh get_ip $device)
  while [[ ! $ip ]]; do
    ip=$($DIR/scripts/utils.sh get_ip $device)
    sleep 1
  done

  rm -f $config
  echo "NETWORK_INTERFACE = "$ip > $config
  echo "DAEMON_LIST = "$daemons >> $config
  echo "CONDOR_HOST = "$server >> $config
  echo "NO_DNS = True" >> $config
  echo "DEFAULT_DOMAIN_NAME = Condor" >> $config
  condor_master
}

function stop() {
  while [[ "$(pgrep openvpn)" || "$(pgrep condor_)" ]]; do
    pkill -KILL openvpn
    pkill -KILL condor_
    sleep 1
  done
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    start
    ;;
  *)
    echo "usage: start, stop, restart"
  ;;
esac

exit 0
