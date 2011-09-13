#!/bin/bash
source /etc/ipop.vpn.config
source /etc/grid_appliance.config
source /etc/group_appliance.config
config=$DIR"/etc/condor_config.d/00root"
whole_machine=$DIR"/etc/condor_config.d/01whole_machine"
userbase=cndrusr

cadduser()
{
  user=$userbase$1
  echo "SLOT"$1"_USER = "$user >> $config
  id $user &> /dev/null
  if [[ $? -eq 0 ]]; then
    return
  fi
  useradd $user
}

# Prepare the accounts for usage by condor as well as a single whole slot
prepare_slots()
{
  slots=$(cat /proc/cpuinfo | grep processor | wc -l)
  for (( i = 1 ; $i <= $slots; i = $i + 1 )); do
    cadduser $i
  done
  # condor_whole_machine disabled
#  if [[ $slots -gt 1 ]]; then
#    condor_whole_machine
#  fi
}

condor_whole_machine()
{
  cp $DIR"/etc/condor_whole_machine" $whole_machine
  slotpp=$(expr $slots + 1)
  for (( i = 1 ; $i < $slots; i = $i + 1 )); do
    echo "  (Slot"$i"_State =?= \"Claimed\") + \\" >> $whole_machine
  done

  cadduser $slotpp
  echo "  (Slot"$slots"_State =?= \"Claimed\")" >> $whole_machine
  # Detect if the whole slot is being used
  echo "WHOLE_MACHINE_SLOT_CLAIMED = (Slot"$slotpp"_State =?= \"Claimed\")" >> $whole_machine
  # 7.4 has DETECTED_*, 7.2 doesn't
  echo "GA_DETECTED_CORES = $slots" >> $whole_machine
  memory=$(free -m | grep Mem | awk '{print $2}')
  echo "GA_DETECTED_MEMORY = $memory" >> $whole_machine
  # we will double-allocate resources to overlapping slots
  # 7.4 supports operators on apparently all configuration variables
  echo "NUM_CPUS = $(expr $slots \* 2)" >> $whole_machine
  echo "MEMORY = $(expr $memory \* 2)" >> $whole_machine
  # Slot number for whole machine
  echo "WHOLE_MACHINE_SLOT = $slotpp" >> $whole_machine
}

configure_condor()
{
  ipop_ns=`$DIR/scripts/utils.sh get_ipopns`
#  We bind to all interfaces for condor interface to work
  ip=`$DIR/scripts/utils.sh get_ip $DEVICE`
  rm -f $config
  echo "NETWORK_INTERFACE = "$ip > $config

# Clean up any potentially stale Server entries
  registered=`$DIR/scripts/DhtHelper.py dump $ipop_ns:condor:server`
  for reg in $registered; do
    $DIR/scripts/DhtHelper.py unregister $ipop_ns:condor:server $reg
  done

  if [[ $MACHINE_TYPE = "Server" ]]; then
    $DIR/scripts/DhtHelper.py register $ipop_ns:condor:server $ip 600
    server=$ip
  else
    server=`$DIR/scripts/DhtHelper.py get server $ipop_ns`
    if [[ ! "$server" ]]; then
      logger -s -t "Condor" "Unable to find a server.  Try again later."
      exit 1
    fi
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

  prepare_slots
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

start_condor()
{
  if ! test -e /var/run/condor; then
    mkdir /var/run/condor
    chown condor:condor /var/run/condor
  fi

  configure_condor
  if [[ $? != 0 ]]; then
    logger -s -t "Condor" "Failed to configure... try again later..."
    exit 1
  fi
  # This is run to limit the amount of memory condor jobs can use - up to the  contents
  # of physical memory, that means a swap disk is necessary!
  ulimit -v `cat /proc/meminfo | grep MemTotal | awk -F" " '{print $2}'`

  # Turn on the firewall
  slots=$(cat /proc/cpuinfo | grep processor | wc -l)
  for (( i = 1 ; $i <= $slots; i = $i + 1 )); do
    $DIR/scripts/utils.sh firewall_stop $userbase$i
    $DIR/scripts/utils.sh firewall_start $userbase$i
  done

  condor_master
}

stop_condor()
{
  # Shutdown the firewall
  slots=$(cat /proc/cpuinfo | grep processor | wc -l)
  for (( i = 1 ; $i <= $slots; i = $i + 1 )); do
    $DIR/scripts/utils.sh firewall_stop $userbase$i
  done

  msg=$(condor_off -subsystem master 2>&1)
  # condor_off is a nice way to shut things down, but sometimes, frequently enough, it doesn't
  for (( count = 0; $count < 5; count = $count + 1 )); do
    if [[ ! "$(pgrep condor_)" ]]; then
      exit 0
    fi
    sleep 1
  done
  pkill -KILL condor_
}

if test -e $DIR/etc/not_configured; then
  logger -s -t "Condor" "Grid Appliance not configured!"
  exit 1
fi

if [[ $1 == "start" ]]; then
  start_condor
elif [[ $1 == "restart" ]]; then
  $DIR/scripts/condor.sh stop
  $DIR/scripts/condor.sh start
elif [[ $1 == "stop" ]]; then
  stop_condor
elif [[ $1 == "reconfig" ]]; then
  configure_condor
  if [[ $? != 0 ]]; then
    logger -s -t "Condor" "Failed to configure... try again later..."
    exit 1
  fi
  condor_reconfig
fi

exit 0
