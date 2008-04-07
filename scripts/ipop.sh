#!/bin/bash
dir="/usr/local/ipop"
device=`cat $dir/etc/device`

if ! `$dir/scripts/utils.sh check_fd`; then
  exit
fi

if [[ $1 == "stop" || $1 == "restart" ]]; then
  echo "Stopping Grid Services..."
  pid=`$dir/scripts/utils.sh get_pid CondorIpopNode`
  if [ $pid ]; then
    kill -SIGINT $pid
    sleep 5
    kill -KILL $pid
  fi
fi

if [[ $1 == "start" || $1 == "restart" ]]; then
  echo "Starting Grid Services..."

  # Create config file for IPOP and start it up
  if test -f $dir/var/ipop_ns; then
    if [[ `cat $dir/var/ipop_ns` == `cat /mnt/fd/ipop_ns` ]]; then
      new_config=0
    else
      new_config=1
    fi
  else
    new_config=1
  fi

  if [[ $new_config == 1 ]]; then
    echo "Generating new IPOP configuration"
    cp /mnt/fd/ipop_ns $dir/var/ipop_ns
    ipop_ns=`cat $dir/var/ipop_ns`
    sed s/NAMESPACE/$ipop_ns/ $dir/etc/ipop.config > $dir/var/ipop.config
    cp /mnt/fd/node.config $dir/var/node.config
  fi

  cd $dir/tools
  rm -rf data
  oldhostname=`hostname`
  hostname localhost
  mono CondorIpopNode.exe $dir/var/node.config $dir/var/ipop.config 2>&1 | /usr/bin/cronolog --period="1 day" --symlink=$dir/var/ipoplog $dir/var/ipop.log.%y%m%d &
  pid=`$dir/scripts/utils.sh get_pid CondorIpopNode`
  while [ ! $pid ]; do
    sleep 5
    pid=`$dir/scripts/utils.sh get_pid CondorIpopNode`
  done
  sleep 3
  test=`/sbin/ifconfig tapipop | grep tapipop`
  if test -z "$test"; then
    $dir/scripts/ipop.sh restart
    exit
  fi
  renice -19 -p $pid

  if [ ! `$dir/scripts/utils.sh get_pid DhtProxy` ]; then
    $dir/scripts/DhtProxy.py &
    $dir/scripts/DhtHelper.py register dhcp:ipop_namespace:`cat /mnt/fd/ipop_ns` `cat /mnt/fd/dhcpdata.conf` 302400 &
  fi

  hostname $oldhostname
  dhclient3 -pf /var/run/dhclient.$device.pid -lf /var/lib/dhcp3/dhclient.$device.leases $device

  cd -
  ln -sf $dir/var/ipoplog /var/log/ipop

  echo "IPOP has started"
  $dir/scripts/iprules &
fi
