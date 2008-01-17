#!/bin/bash
dir="/usr/local/ipop"
VMM=`$dir/scripts/utils.sh vmm`

if [ -d /.unionfs/.unionfs ]; then
  file=/.unionfs/.unionfs/swapfile
else
  file=/.unionfs/swapfile
fi

rm -rf $file &> /dev/null
dd if=/dev/zero of=$file bs=1024K count=128
mkswap $file
swapon $file

$dir/scripts/maintenance.sh start &

#Admin SSH
/usr/sbin/sshd -f /root/.ssh/sshd_config

python $dir/scripts/dns.py &
$dir/scripts/ippoll.sh &> /var/log/ippoll.log &

if [[ $VMM = "vmware" ]]; then
  ln -sf $dir/etc/xorg.conf.vmware /etc/X11/xorg.conf
else
  ln -sf $dir/etc/xorg.conf.vesa /etc/X11/xorg.conf
fi

if [[ `cat /mnt/fd/type` == "Client" ]]; then
  rm /home/griduser/.xison &> /dev/null
  cd /home/griduser
  su griduser /home/griduser/startx.sh &
  cd -
fi

clear
