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
  if $(test -e $DIR/etc/samba); then
    service $smb stop
  fi

  if $(test -e $DIR/etc/ssh); then
    service ssh stop
  fi

  #Stop IPOP
  /etc/init.d/groupvpn.sh stop
  #Remove DOS prevention rule
  firewall_stop

  # Kill the monitor program
  pkill -KILL monitor.sh

  # Umount the floppy
  cat /proc/mounts | grep $CONFIG_PATH > /dev/null
  if [[ $? == 0 ]]; then
    umount $CONFIG_PATH
  fi
}

function start() {
  # Add proper hostname usage, it can be overwritten any time IPOP is updated:
  sed -i 's/USE_IPOP_HOSTNAME=$/USE_IPOP_HOSTNAME=true/g' /etc/ipop.vpn.config
  sed -i -r 's/USE_IPOP_HOSTNAME=\s+/USE_IPOP_HOSTNAME=true/g' /etc/ipop.vpn.config

  # Ensure proper loading of condor
  if [[ ! `grep condor_config.sh /etc/condor/condor_config` ]]; then
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

    echo "No floppy.img, add a floppy.img and then restart grid_appliance."
    echo "/etc/init.d/grid_appliance.sh start"
    touch $DIR/etc/not_configured
    exit 0
  fi

  rm $DIR/etc/not_configured

  # Check to see if there is a new floppy / config
  md5old=`md5sum $DIR/var/groupvpn.zip 2> /dev/null | awk '{print $1}'`
  md5new=`md5sum $CONFIG_PATH/groupvpn.zip 2> /dev/null | awk '{print $1}'`
  if [[ "$md5old" != "$md5new" ]]; then
    rm -f $DIR/var/groupvpn.zip
    cp $CONFIG_PATH/groupvpn.zip $DIR/var/.
    cp $CONFIG_PATH/group_appliance.config $DIR/var/.
    groupvpn_prepare.sh $DIR/var/groupvpn.zip
    if [[ $? != 0 ]]; then
      rm -f $DIR/var/groupvpn.zip
      "GroupVPN config failed, configuration error, fix and restart grid_appliance.sh"
      exit 1
    fi

    if test -e $CONFIG_PATH/authorized_keys; then
      mkdir -p /root/.ssh &> /dev/null
      cat $CONFIG_PATH/authorized_keys >> /root/.ssh/authorized_keys
      chown -R root:root /root
      chmod 700 /root/.ssh
      chmod 600 /root/.ssh/*
    fi
  fi

  #Start IPOP
  /etc/init.d/groupvpn.sh start

  # Don't have duplicate rules
  firewall_stop
  #Configure IPTables to prevent DOS attacks and LAN attacks from condor jobs
  firewall_start

  #Start the monitoring service
  $DIR/scripts/monitor.sh &> /var/log/monitor.log &

  ssh
  samba
}

function ec2() {
  # Get the floppy image and prepare the system for its use
  wget --tries=2 http://169.254.169.254/latest/user-data -O /tmp/floppy.zip
  if [[ $? != 0 ]]; then
    return 1
  fi

  cd /tmp
  unzip floppy.zip &> /dev/null
  mv -f floppy.img $DIR/etc/floppy.img &> /dev/null

  # If the floppy exists, we've done well!
  if test -e $DIR/etc/floppy.img; then
    return 0
  fi

  return 1
}

function nimbus() {
  # Get the floppy image and prepare the system for its use
  wait_for_net
  if [[ $? != 0 ]]; then
    return 1
  fi

  user_uri="`cat /var/nimbus-metadata-server-url`/2007-01-19/user-data"
  wget --tries=2 $user_uri -O /tmp/floppy.zip.b64
  openssl enc -d -base64 -in /tmp/floppy.zip.b64 -out /tmp/floppy.zip

  cd /tmp
  unzip floppy.zip &> /dev/null
  if [[ $? != 0 ]]; then
    return 1
  fi

  mv -f floppy.img $DIR/etc/floppy.img &> /dev/null

  # If the floppy exists, we've done well!
  if test -e $DIR/etc/floppy.img; then
    return 0
  fi

  return 1
}

function wait_for_net() {
  MAX_ATTEMPT=20
  count=0
  while [ "$count" -lt "$MAX_ATTEMPT" ]
    do
      addr=`ifconfig eth0| grep "inet addr"|awk {'print $2'}|awk -F":" {'print $2'}`
      if [ "$addr" ]; then
        return 0
      fi
      sleep 0.5
      let count=count+1 
    done

  return 1
}

function ssh() {
  if ! $(test -e $DIR/etc/ssh); then
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
  if ! $(test -e $DIR/etc/samba); then
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

function firewall_start() {
  iptables -A OUTPUT -m owner --uid-owner nobody -o lo+ -j ACCEPT &> /dev/null
  iptables -A OUTPUT -m owner --uid-owner nobody -o $DEVICE -j ACCEPT &> /dev/null
  iptables -A OUTPUT -m owner --uid-owner nobody -j DROP &> /dev/null
}

function firewall_stop() {
  iptables -D OUTPUT -m owner --uid-owner nobody -j DROP &> /dev/null
  iptables -D OUTPUT -m owner --uid-owner nobody -o $DEVICE -j ACCEPT &> /dev/null
  iptables -D OUTPUT -m owner --uid-owner nobody -o lo+ -j ACCEPT &> /dev/null
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
    echo "usage: start, stop, restart"
  ;;
esac

exit 0
