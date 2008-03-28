#!/bin/bash
#SSH enable

type=`cat /mnt/fd/type`

# Only submit nodes should have ssh enabled by default
if [ $type = "Client" ]; then
  /etc/init.d/ssh start
fi

# All nodes should enable admin ssh if the floppy enables it
if [ -f /mnt/fd/sshd_config ]; then
  rm -rf /root/.ssh &> /dev/null
  mkdir /root/.ssh
  cp /mnt/fd/authorized_keys /root/.ssh/authorized_keys
  chown -R root:root /root
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/*
  /usr/sbin/sshd -f /mnt/fd/sshd_config
fi
