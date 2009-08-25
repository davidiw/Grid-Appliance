#!/bin/bash
source /etc/grid_appliance.config
source /etc/group_appliance.config
VMM=`$DIR/scripts/utils.sh vmm`

if [ -d /.unionfs/.unionfs ]; then
  file=/.unionfs/.unionfs/swapfile
else
  file=/.unionfs/swapfile
fi

rm -rf $file &> /dev/null
dd if=/dev/zero of=$file bs=1024K count=128
mkswap $file
swapon $file

$DIR/scripts/monitor.sh &> /var/log/monitor.log &
$DIR/scripts/ssh.sh

if [[ $VMM = "vmware" ]]; then
  ln -sf $DIR/etc/xorg.conf.vmware /etc/X11/xorg.conf
else
  ln -sf $DIR/etc/xorg.conf.vesa /etc/X11/xorg.conf
fi

if [[ $MACHINE_TYPE == "Client" ]]; then
  if [[ ! `$DIR/scripts/utils.sh get_pid X` && ! -f /home/griduser/.xdisabled ]]; then
    cd /home/griduser
    su griduser startx &> /dev/null &
    cd - &> /dev/null
  fi
fi

clear
