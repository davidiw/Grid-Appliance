#!/bin/bash
source /etc/ipop.vpn.config

function get_pid()
{
  ps -eo pid,cmd | grep $1 | grep -v grep | grep -v get_pid | grep -oE "[0-9]+"
}

function trace()
{
  pid=$(get_pid DhtIpopNode.exe)
  if [[ $pid ]]; then
    kill -USR2 $pid
  fi
}

function stop()
{
  echo "Stopping IPOP..."

  dhcp_pid=$(get_pid tapipop)
  if [[ $dhcp_pid ]]; then
    kill -KILL $dhcp_pid
  fi

  pid=$(get_pid DhtIpopNode.exe)

  if [[ $pid ]]; then
    if [[ "$USE_IPOP_HOSTNAME" ]]; then
      hostname localhost
    fi
    $DIR/bin/dump_dht_proxy.py $DIR/etc/dht_proxy
    kill -SIGINT $pid &> /dev/null

    pid=$(get_pid DhtIpopNode.exe)
    while [[ "$pid" ]]; do
      pid=$(get_pid DhtIpopNode.exe)
      sleep 5
      kill -KILL $pid &> /dev/null
    done
  fi

  echo "Shutting off the TAP device"
  if [[ -e /proc/sys/net/ipv4/neigh/tapipop ]]; then
    tunctl -d tapipop 2>&1 | logger -t ipop
  fi

  echo "Stopped IPOP..."
}

function start()
{
  echo "Starting IPOP..."
  pid=$(get_pid DhtIpopNode.exe)
  if [[ $pid ]]; then
    echo "IPOP Already running..."
    return 1
  fi

  if [[ "$USER" ]]; then
    chown -R $USER $DIR/etc
    chown -R $USER $DIR/var
    user="--user="$USER
    tunctl_user="-u "$USER
    if [[ "$GROUP" ]]; then
      group="--group="$GROUP
    fi
  fi

  if [[ "$USE_IPOP_HOSTNAME" ]]; then
    #service will throw exceptions if we don't have a FQDN
    hostname localhost
    if [[ ! "$STATIC" ]]; then
      exit_hook=/etc/dhcp3/dhclient-exit-hooks.d
      if test -e $exit_hook; then
        if ! test -e $exit_hook/ipop_hostname; then
          ln -s $DIR/bin/hostname.sh $exit_hook/ipop_hostname
        fi
      fi
    fi
  fi

  if [[ ! -e /dev/net/tun ]]; then
    mkdir /dev/net
    mknod /dev/net/tun c 10 200
    chmod 666 /dev/net/tun
  fi

  if [[ ! -e /proc/sys/net/ipv4/neigh/tapipop ]]; then
    chmod 666 /dev/net/tun
    tunctl -t tapipop $tunctl_user &> /dev/null
  fi

  cd $DIR/bin &> /dev/null
  export MONO_PATH=$MONO_PATH:$DIR/lib
#trace is only enabled to help find bugs, to use it execute groupvpn.sh trace
  python daemon.py $user $group "mono --trace=disabled DhtIpopNode.exe -n $DIR/etc/node.config -i $DIR/etc/ipop.config -d $DIR/etc/dhcp.config 2>&1 | cronolog --period=\"1 day\" --symlink=$DIR/var/ipoplog $DIR/var/ipop.log.%y%m%d"
  cd - &> /dev/null
  pid=$(get_pid DhtIpopNode.exe)
  if [[ ! $pid ]]; then
    sleep 5
    pid=$(get_pid DhtIpopNode.exe)
  fi

  if [[ ! $pid ]]; then
    echo "Error starting IPOP!"
    exit
  fi

  if [[ -e $DIR/etc/dht_proxy ]]; then
    $DIR/bin/load_dht_proxy.py $DIR/etc/dht_proxy &> /dev/null
    result=$?
    while [[ $result == 1 && $pid && -e $DIR/etc/dht_proxy ]]; do
      $DIR/bin/load_dht_proxy.py $DIR/etc/dht_proxy &> /dev/null
      result=$?
      pid=$(get_pid DhtIpopNode.exe)
    done
  fi

  renice -19 -p $pid &> /dev/null

  if [[ "$STATIC" ]]; then
    ifconfig $DEVICE $IP netmask $NETMASK mtu 1200
    if [[ "$USE_IPOP_HOSTNAME" ]]; then
      $DIR/bin/hostname.sh
    fi
  else
    if [[ ! "$DHCP" ]]; then
      if [[ "$(which dhclient3 2> /dev/null)" ]]; then
        DHCP="dhclient3 -pf /var/run/dhclient.$DEVICE.pid -lf /var/lib/dhcp3/dhclient.$DEVICE.leases $DEVICE"
      elif [[ "$(which dhcpcd 2> /dev/null)" ]]; then
        DHCP="dhcpcd $DEVICE"
      elif [[ "$(which dhclient 2> /dev/null)" ]]; then
        DHCP="dhclient -nw -pf /var/run/dhclient.$DEVICE.pid -lf /var/lib/dhcp/dhclient.$DEVICE.leases $DEVICE"
      else
        echo "No valid DHCP client"
        exit
      fi
    fi
    $DHCP &> /var/log/ipop.dhcp.log <&- &
  fi

# setup logging
  ln -sf $DIR/var/ipoplog /var/log/ipop
  echo "Started IPOP..."
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
  trace)
    trace
    ;;
  *)
    echo "usage: start, stop, restart, trace"
    ;;
esac
exit 0
