#!/bin/bash
source /etc/ipop.vpn.config
source /etc/grid_appliance.config
source /etc/group_appliance.config
config=$DIR"/etc/condor_config.d/00root"

configure_condor()
{
  ipop_ns=`$DIR/scripts/utils.sh get_ipopns`
#  We bind to all interfaces for condor interface to work
  ip=`$DIR/scripts/utils.sh get_ip $DEVICE`
  rm -f $config
  echo "NETWORK_INTERFACE = "$ip > $config

  if [[ $MACHINE_TYPE = "Server" ]]; then
    registered=`$DIR/scripts/DhtHelper.py dump $ipop_ns:condor:server`
    for reg in $registered; do
      $DIR/scripts/DhtHelper.py unregister $ipop_ns:condor:server $reg
    done
    $DIR/scripts/DhtHelper.py register $ipop_ns:condor:server $ip 600
    server=$ip
  else
    server=`$DIR/scripts/DhtHelper.py get server $ipop_ns`
    while [[ ! $server ]]; do
      sleep 15
      server=`$DIR/scripts/DhtHelper.py get server $ipop_ns`
    done
  fi
  flock=`$DIR/scripts/DhtHelper.py get flock $ipop_ns`

  if [[ $MACHINE_TYPE = "Server" ]]; then
    DAEMONS="MASTER, COLLECTOR, NEGOTIATOR"
  elif [[ $MACHINE_TYPE = "Submit" ]]; then
    DAEMONS="MASTER, SCHEDD"
  elif [[ $MACHINE_TYPE = "Worker" ]]; then
    DAEMONS="MASTER, STARTD"
  else #$MACHINE_TYPE = Client
    DAEMONS="MASTER, STARTD, SCHEDD, KBDD"
  fi

  submit_exprs=""
  startd_attrs=""

  echo "DAEMON_LIST = "$DAEMONS >> $config
  echo "CONDOR_HOST = "$server >> $config
  rm -f $DIR/var/condor_manager
  echo $server > $DIR/var/condor_manager
  echo "FLOCK_TO = "$flock >> $config
  rm -f $DIR/var/condor_flock
  echo $flock > $DIR/var/condor_flock

  if [[ "$CONDOR_GROUP" ]]; then
    echo "Group = \"$CONDOR_GROUP\"" >> $config
    echo "RANK = TARGET.Group =?= MY.Group" >> $config
    startd_attrs=$startd_attrs", Group"
    echo "SUBMIT_EXPRS = \$(SUBMIT_EXPRS), Group" >> $config
    submit_exprs=$submit_exprs", Group"
    if [[ $MACHINE_TYPE = "Server" ]]; then
      echo "NEGOTIATOR_PRE_JOB_RANK = 10 * (MY.RANK) + 1 * (RemoteOwner =?= UNDEFINED)" >> $config
    fi
  fi

  if [[ "$CONDOR_USER" ]]; then
    echo "User = \"$CONDOR_USER\"" >> $config
    startd_attrs=$startd_attrs", User"
    submit_exprs=$submit_exprs", User"
    if [[ $CONDOR_GROUP ]]; then
      echo "AccountGroup = \"$CONDOR_GROUP.$CONDOR_USER\"" >> $config
      submit_exprs=", AccountingGroup"
    fi
    submit_exprs=", AccountingGroup"
  fi

  echo "APPLIANCE_VERSION = $(cat $DIR/etc/version)" >> $config
  startd_attrs=$startd_attrs", APPLIANCE_VERSION"
  echo "SUBMIT_EXPRS = \$(SUBMIT_EXPRS)"$submit_exprs >> $config
  echo "STARTD_ATTRS = \$(STARTD_ATTRS)"$startd_attrs >> $config
}

update_flock()
{
  ipop_ns=`$DIR/scripts/utils.sh get_ipopns`
  flock=`cat /etc/condor/flock`
  new_flock=`$DIR/scripts/DhtHelper.py get flock $ipop_ns`
  if [[ $flock != $new_flock ]]; then
    echo "FLOCK_TO = "$flock >> $config
    echo $flock > $DIR/var/condor_flock
    condor_reconfig
  fi
}

if test -e $DIR/etc/not_configured; then
  echo "Grid Appliance not configured!"
  exit -1
fi

if [[ $1 = "start" ]]; then
  configure_condor
  # This is run to limit the amount of memory condor jobs can use - up to the  contents
  # of physical memory, that means a swap disk is necessary!
  ulimit -v `cat /proc/meminfo | grep MemTotal | awk -F" " '{print $2}'`
  condor_master
elif [[ $1 = "restart" ]]; then
  $DIR/scripts/condor.sh stop
  $DIR/scripts/condor.sh start
elif [[ $1 = "stop" ]]; then
  msg=$(condor_off -subsystem master 2>&1)
  # If our IP address changed, we won't be able to kill condor via condor_off
  if [[ $msg == "Can't connect to local master" ]]; then
    pkill -KILL condor_
  fi
elif [[ $1 = "reconfig" ]]; then
  configure_condor
  condor_reconfig
fi

exit 0
