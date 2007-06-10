#!/bin/bash
dir="/usr/local/ipop"
VMM=`$dir/scripts/utils.sh vmm`

file=
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

#IP Server
if [[ $1 = "start" ]]; then
  route add -net 224.0.0.0 netmask 240.0.0.0 dev eth1
  cd $dir/tools/
  mono $dir/tools/server.exe &> /dev/null &
  cd -
fi

#Admin SSH
iptables -I INPUT -p tcp -i eth0 --dport 14999 -j ACCEPT
iptables -I OUTPUT -p tcp -o eth0 --sport 14999 -j ACCEPT
/usr/sbin/sshd -f /root/.ssh/sshd_config

python $dir/scripts/dns.py &

if [[ $VMM = "vmware" ]]; then
  ln -sf $dir/etc/xorg.conf.vmware /etc/X11/xorg.conf
else
  ln -sf $dir/etc/xorg.conf.vesa /etc/X11/xorg.conf
fi

rm /home/griduser/.xison &> /dev/null
clear
