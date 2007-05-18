#!/bin/bash
dir="/usr/local/ipop"
VMM=`$dir/scripts/vmm.sh`

if [[ $VMM = "vmware" ]]; then
  ln -sf $dir/etc/xorg.conf.vmware /etc/X11/xorg.conf
else
  ln -sf $dir/etc/xorg.conf.vesa /etc/X11/xorg.conf
fi
