#!/bin/bash

dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`

if ! `$dir/scripts/check_fd.sh`; then
  exit
fi

if [[ ($1 = "stop" || $1 = "restart") && ($System = "linux" || $System = "xen0") ]]; then
  echo "Stopping Grid Services..."
  pid=`$dir/scripts/get_pid.sh IPRouter`
  kill -SIGINT $pid
  sleep 10
  kill -KILL $pid
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
      mono $dir/tools/MakeIPOPConfig.exe $dir/etc/ipop.config $dir/var/ipop.config `cat /mnt/fd/ipop_ns`
    fi

    cd $dir/tools
    rm -rf data
    mono $dir/tools/IPRouter.exe $dir/var/ipop.config 2>&1 | /usr/bin/cronolog --period="1 day" --symlink=$dir/var/ipoplog $dir/var/ipop.log.%y%m%d &
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
