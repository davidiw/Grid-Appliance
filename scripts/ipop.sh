#!/bin/bash
DIR="/usr/local/ipop"
DEVICE=`cat $DIR/etc/device`

if ! `$DIR/scripts/utils.sh check_fd`; then
  return 1
fi

function stop()
{
  echo "Stopping Grid Services..."

  pid=`$DIR/scripts/utils.sh get_pid CondorIpopNode`

  if [[ ! $pid ]]; then
    return 1
  fi

  kill -SIGINT $pid &> /dev/null

  while [[ `$DIR/scripts/utils.sh get_pid CondorIpopNode` ]]; do
    sleep 5
    kill -KILL $pid &> /dev/null
  done

  if [[ -e /proc/sys/net/ipv4/neigh/tapipop ]]; then
    ./tunctl -d tapipop 2>1 | logger -t ipop
  fi
}

function start()
{
  pid=`$DIR/scripts/utils.sh get_pid CondorIpopNode`

  if [[ $pid ]]; then
    echo "IPOP Already running..."
    return 1
  fi

  # Create config file for IPOP and start it up
  new_config=true
  if [[ -e $DIR/var/ipop_ns ]]; then
    if [[ `cat $DIR/var/ipop_ns` == `cat /mnt/fd/ipop_ns` ]]; then
      unset new_config
    fi
  fi

  if [[ $new_config ]]; then
    echo "Generating new IPOP configuration"
    cp /mnt/fd/ipop_ns $DIR/var/ipop_ns
    ipop_ns=`cat $DIR/var/ipop_ns`
    sed s/NAMESPACE/$ipop_ns/ $DIR/etc/ipop.config > $DIR/var/ipop.config
    cp /mnt/fd/node.config $DIR/var/node.config
    if [[ -f /mnt/fd/ipopsec_server ]]; then
      cd $DIR/tools
      rm -f private_key
      mono Keymaker.exe
      mv rsa_private private_key
      rm -f rsa_public
      cd -
      sed 's/<EndToEndSecurity>false/<EndToEndSecurity>true/' -i $DIR/var/ipop.config
      sed -n '1h;1!H;${;g;s/<Security>\s*<Enabled>false/<Security>\n    <Enabled>true/g;p;}' -i $DIR/var/node.config
    fi
  fi

  cd $DIR/tools
  rm -rf data
#service will throw exceptions if we don't have a FQDN
  oldhostname=`hostname`
  hostname localhost
  if [[ ! -e /proc/sys/net/ipv4/neigh/tapipop ]]; then
    ./tunctl -t tapipop 2>1 | logger -t ipop
  fi
#trace is only enabled to help find bugs, to use it execute kill -USR2 $CondorIpopNode_PID
  mono --trace=disabled CondorIpopNode.exe $DIR/var/node.config $DIR/var/ipop.config 2>&1 | /usr/bin/cronolog --period="1 day" --symlink=$DIR/var/ipoplog $DIR/var/ipop.log.%y%m%d &
  pid=`$DIR/scripts/utils.sh get_pid CondorIpopNode`
  if [[ ! $pid ]]; then
    sleep 5
  fi

  pid=`$DIR/scripts/utils.sh get_pid CondorIpopNode`
  renice -19 -p $pid
  cd -

# only need one DhtProxy
  if [ ! `$DIR/scripts/utils.sh get_pid DhtProxy` ]; then
    $DIR/scripts/DhtProxy.py &
    $DIR/scripts/DhtHelper.py register dhcp:ipop_namespace:`cat /mnt/fd/ipop_ns` `cat /mnt/fd/dhcpdata.conf` 302400 &
  fi

  dhclient3 -pf /var/run/dhclient.$DEVICE.pid -lf /var/lib/dhcp3/dhclient.$DEVICE.leases $DEVICE

# setup logging
  ln -sf $DIR/var/ipoplog /var/log/ipop

  $DIR/scripts/iprules &
  echo "IPOP has started"
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
esac
exit 0
