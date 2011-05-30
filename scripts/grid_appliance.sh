#!/bin/bash

### BEGIN INIT INFO
# Provides:          grid_appliance
# Required-Start:    $local_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Begins Grid Appliance config and IPOP
# Description:       Enable Grid Appliance, Condor, IPOP
### END INIT INFO

source /etc/ipop.vpn.config
source /etc/grid_appliance.config

smb=samba
if [[ -e /etc/init.d/smbd ]]; then
  smb=smbd
fi

function stop() {
  #We could stop samba and ssh, but that makes things more difficult to debug
  #so from now on, we leave them running, once they've been turned on
  #Stop Condor if running
  if [[ $($DIR/scripts/utils.py check_condor_running) == "True" ]]; then
    $DIR/scripts/condor.sh stop
  fi
  #Stop IPOP
  /etc/init.d/groupvpn.sh stop

  # Kill the monitor program
  pkill -KILL monitor.py

  # Umount the floppy
  cat /proc/mounts | grep $CONFIG_PATH > /dev/null
  if [[ $? == 0 ]]; then
    umount $CONFIG_PATH
  fi
}

function start() {
  # Regardless of the success of getting the GA up and running, we should start
  # ssh services so that a user on a cloud can access the instance and add a
  # floppy at run time
  ssh
  # Add proper hostname usage, it can be overwritten any time IPOP is updated:
  sed -i 's/USE_IPOP_HOSTNAME=$/USE_IPOP_HOSTNAME=true/g' /etc/ipop.vpn.config
  sed -i -r 's/USE_IPOP_HOSTNAME=\s+/USE_IPOP_HOSTNAME=true/g' /etc/ipop.vpn.config

  # Ensure proper loading of condor
  if [[ ! $(grep condor_config.sh /etc/condor/condor_config) ]]; then
    echo "LOCAL_CONFIG_FILE  = /etc/condor/condor_config.sh|" >> /etc/condor/condor_config
  fi

  # Mount the floppy, umount first
  cat /proc/mounts | grep $CONFIG_PATH > /dev/null
  if [[ $? == 0 ]]; then
    umount $CONFIG_PATH
  fi

  # Create the path if necessary
  if ! test -d $CONFIG_PATH; then
    mkdir $CONFIG_PATH &> /dev/null
  fi

  try_fd=true
  # Determine which device and mount
  if test -e $DIR/etc/floppy.img; then
    # Secure our private data!
    chmod 700 $DIR/etc/floppy.img
    mount -o loop $DIR/etc/floppy.img $CONFIG_PATH
    if [[ $? == 0 ]]; then
      try_fd=
    fi
  fi

  if [[ "$try_fd" ]]; then
    modprobe floppy
    mount /dev/fd0 $CONFIG_PATH
  fi

  # If we didn't mount a floppy, no point in proceeding!
  cat /proc/mounts | grep $CONFIG_PATH > /dev/null
  if [[ $? != 0 ]]; then
    logger -s -t "Grid Appliance" "No local floppy, trying for cloud floppy..."
    # Get the floppy image and prepare the system for its use
    wait_for_net
    if [[ $? != 0 ]]; then
      return 1
    fi

    ec2
    if [[ $? == 0 ]]; then
      start
      return
    fi

    nimbus
    if [[ $? == 0 ]]; then
      start
      return
    fi

    logger -s -t "Grid Appliance" "No floppy.img, add a floppy.img and then restart grid_appliance."
    logger -s -t "Grid Appliance" "/etc/init.d/grid_appliance.sh start"
    touch $DIR/etc/not_configured
    exit 0
  fi

  if test -e $DIR/etc/not_configured; then
    rm $DIR/etc/not_configured
  fi

  # Check to see if there is a new floppy / config
  md5old=$(md5sum $DIR/var/groupvpn.zip 2> /dev/null | awk '{print $1}')
  md5new=$(md5sum $CONFIG_PATH/groupvpn.zip 2> /dev/null | awk '{print $1}')
  if [[ "$md5old" != "$md5new" ]]; then
    rm -f $DIR/var/groupvpn.zip
    cp $CONFIG_PATH/groupvpn.zip $DIR/var/.
    cp $CONFIG_PATH/group_appliance.config $DIR/var/.
    groupvpn_prepare.sh $DIR/var/groupvpn.zip
    if [[ $? != 0 ]]; then
      rm -f $DIR/var/groupvpn.zip
      logger -s -t "Grid Appliance" "GroupVPN config failed, configuration error, fix and restart grid_appliance.sh"
      exit 1
    fi

    if test -e $CONFIG_PATH/authorized_keys; then
      mkdir -p /root/.ssh &> /dev/null
      if ! test -e /root/.ssh/authorized_keys.bak; then
        cp /root/.ssh/authorized_keys /root/.ssh/authorized_keys.bak
      else
        touch /root/.ssh/authorized_keys.bak
      fi
      cat $CONFIG_PATH/authorized_keys >> /root/.ssh/authorized_keys
      chown -R root:root /root
      chmod 700 /root/.ssh
      chmod 600 /root/.ssh/*
    fi
  fi

  #Start IPOP
  /etc/init.d/groupvpn.sh start

  #Start the monitoring service
  $DIR/scripts/monitor.py

  user
}

function ec2() {
  # Get the floppy image and prepare the system for its use
  wget --quiet --tries=2 http://169.254.169.254/latest/user-data -O /tmp/floppy.zip
  if [[ $? != 0 ]]; then
    return 1
  fi

  MAX_ATTEMPTS=30
  count=0
  while [[ $(ls -l /tmp/floppy.zip | awk '{print $5}') == 0  && $count -lt $MAX_ATTEMPTS ]]; do
    wget --quiet http://169.254.169.254/latest/user-data -O /tmp/floppy.zip
    count=$((count + 1))
    sleep 1
  done

  if [[ $(ls -l /tmp/floppy.zip | awk '{print $5}') == 0 ]]; then
    logger -s -t "Grid Appliance" "On EC2 / Eucalyptus but could not get user data"
    return 1
  fi

  cloud_floppy
  return $?
}

function nimbus() {
user_uri="$(cat /var/nimbus-metadata-server-url)/2007-01-19/user-data"
  wget --quiet --tries=2 $user_uri -O /tmp/floppy.zip
  if [[ $? != 0 ]]; then
    return 1
  fi

  cloud_floppy
  return $?
}

function cloud_floppy() {
  cd /tmp
  unzip floppy.zip &> /dev/null

  # ec2 converts user-data into base64, eucalyptus doesn't, the user must
  if [[ $? != 0 ]]; then
    mv floppy.zip floppy.zip.b64
    openssl enc -d -base64 -in /tmp/floppy.zip.b64 -out /tmp/floppy.zip
    unzip floppy.zip &> /dev/null
    if [[ $? != 0 ]]; then
      logger -s -t "Grid Appliance" "Unable to extract cloud floppy..."
      return 1
    fi
  fi

  mv -f floppy.img $DIR/etc/floppy.img &> /dev/null

  # If the floppy exists, we've done well!
  if test -e $DIR/etc/floppy.img; then
    return 0
  fi

  logger -s -t "Grid Appliance" "Cannot find cloud floppy..."
  return 1
}

function wait_for_net() {
  MAX_ATTEMPTS=30
  count=0
  for (( count = 0; $count < $MAX_ATTEMPTS; count = $count + 1 )); do
    if [[ "$($DIR/scripts/utils.sh get_ip eth0)" ]]; then
      return 0
    fi
    sleep 1
  done

  logger -s -t "Grid Appliance" "Networking not available..."
  return 1
}

function ssh() {
  if [[ ! -e $DIR/etc/sshd_config ]]; then
    return
  fi

  cidr=$($DIR/scripts/utils.sh get_cidr eth1)
  if [[ ! "$cidr" ]]; then
    cidr="0.0.0.0/32"
  fi
  cidr=$(echo -n $cidr | sed 's/\//\\\//g')

  service ssh stop
  cp -f $DIR/etc/sshd_config /etc/ssh/.
  sed -i "s/HOSTONLY/$cidr/g" /etc/ssh/sshd_config
  service ssh start
}

function samba() {
  if [[ ! -e $DIR/etc/smb.conf ]]; then
    return
  fi

  cidr=$($DIR/scripts/utils.sh get_cidr eth1)
  if [[ ! "$cidr" ]]; then
    cidr="0.0.0.0/32"
  fi
  cidr=$(echo -n $cidr | sed 's/\//\\\//g')

  service $smb stop
  cp -f $DIR/etc/smb.conf /etc/samba/.
  sed -i "s/HOSTONLY/$cidr/g" /etc/samba/smb.conf
  service $smb start
}

function user() {
  source /etc/group_appliance.config
  if [[ $MACHINE_TYPE == "Client" ]]; then
    if ! test -d /home/$CONDOR_USER; then
      $DIR/scripts/utils.sh add_user $CONDOR_USER
    fi
  fi
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
  samba)
    samba
    ;;
  ssh)
    ssh
    ;;
  *)
    logger -s -t "Grid Appliance" "usage: start, stop, restart, samba, ssh"
  ;;
esac

exit 0
