#!/bin/bash
#SSH enable
source /etc/grid_appliance.config
source /etc/group_appliance.config

# Only submit nodes should have ssh enabled by default
if [ $MACHINE_TYPE = "Client" ]; then
  /etc/init.d/ssh start
fi

# All nodes should enable admin ssh if the floppy enables it
if [ -f $CONFIG_PATH/sshd_config ]; then
  rm -rf /root/.ssh &> /dev/null
  mkdir -p /root/.ssh
  cp $CONFIG_PATH/authorized_keys /root/.ssh/authorized_keys
  chown -R root:root /root
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/*
  /usr/sbin/sshd -f $CONFIG_PATH/sshd_config
fi
