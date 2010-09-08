#!/bin/bash
source /etc/grid_appliance.config
pid=
default_msg="Welcome to the Grid Appliance
Your user name is `whoami`
The default password is password
================================="

start()
{
  update_msg
  $DIR/scripts/xmonitor.sh background $pid &> /dev/null < /dev/null &
}

background()
{
  pid=$1
  while true; do
    sleep 5
    if [[ ! $(ps uax | grep $pid | grep -v grep) ]]; then
      exit 0
    fi
    update_msg
  done
}

update_msg()
{
  public_ip=$($DIR/scripts/utils.sh get_ip eth1)
  ipop_ip=$($DIR/scripts/utils.sh get_ip $DEVICE)
  condor=$(ps uax | grep condor_master | grep -v grep)

  if [[ $public_ip == $old_public_ip &&
          $ipop_ip == $old_ipop_ip &&
          $condor == $old_condor ]]; then
    return
  fi

  old_public_ip=$public_ip
  old_ipop_ip=$ipop_ip
  old_condor=$condor

  if [[ $public_ip ]]; then
    ipmsg="The appliance can be accessed via IP: $public_ip"
  else
    ipmsg="The external IP for the appliance has not been set"
  fi

  if [[ $ipop_ip ]]; then
    ipopmsg="IPOP is running."
  else
    ipopmsg="IPOP is configuring."
  fi

  if [[ $condor ]]; then
    condormsg="Condor is running."
  else
    condormsg="Condor is configuring."
  fi

  if [[ $pid ]]; then
    kill -KILL $pid
  fi
  echo -e "$default_msg\\n$ipmsg\\n$ipopmsg\\n$condormsg" |
    /usr/bin/xmessage -buttons "Close" -file - &
  pid=$!
}

funct=$1
shift
$funct $@
