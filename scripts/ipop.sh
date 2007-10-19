#!/bin/bash
dir="/usr/local/ipop"

if ! `$dir/scripts/utils.sh check_fd`; then
  exit
fi

if [ "$2" ]; then
  echo="logger -t ipop"
else
  echo="echo"
fi

if [[ $1 = "stop" || $1 = "restart" ]]; then
  $echo "Stopping Grid Services..."
  pid=`$dir/scripts/utils.sh get_pid IPRouter`
  kill -SIGINT $pid
  sleep 5
  kill -KILL $pid
  if [[ $1 = "stop" ]]; then
    ifdown tap0
    $dir/tools/tunctl -d tap0
  fi

  pid=`$dir/scripts/utils.sh get_pid dhcpdata.conf`
  kill -KILL $pid
fi

if [[ $1 = "start" || $1 = "restart" ]]; then
  $echo "Starting Grid Services..."
  cd $dir/tools/
  mono $dir/tools/SimpleNode.exe -s -df /mnt/fd/dhcpdata.conf &> /dev/null &
  cd -

  if [[ $1 = "start" ]]; then
    # set up tap device
    $dir/tools/tunctl -u root -t tap0 &> /dev/null
    $echo "tap configuration completed"
  fi

  # Create config file for IPOP and start it up
  if test -f $dir/var/ipop_ns; then
    if [[ `cat $dir/var/ipop_ns` = /mnt/fd/ipop_ns ]]; then
      new_config=0
    else
      new_config=1
    fi
  else
    new_config=1
  fi

  if [[ $new_config = 1 ]]; then
    cp /mnt/fd/ipop_ns $dir/var/ipop_ns
    mono $dir/tools/MakeIPRouterConfig.exe $dir/etc/ipop.config /mnt/fd/ipop.config `cat /mnt/fd/ipop_ns`
  fi

  cd $dir/tools
  rm -rf data
  mono $dir/tools/IPRouter.exe $dir/var/ipop.config 2>&1 | /usr/bin/cronolog --period="1 day" --symlink=$dir/var/ipoplog $dir/var/ipop.log.%y%m%d &
  pid=`$dir/scripts/utils.sh get_pid IPRouter`
  while [[ $pid = "" ]]; do
    sleep 5
    pid=`$dir/scripts/utils.sh get_pid IPRouter`
  done

  renice -19 -p $pid

  cd -
  ln -sf $dir/var/ipoplog /var/log/ipop

  $echo "IPOP has started"
  $dir/scripts/iprules &
  if [[ $1 = "restart" ]]; then
    ifconfig tap0 up
    $dir/scripts/utils.sh ping_test 10.191.255.254 &> /dev/null
  fi
fi
