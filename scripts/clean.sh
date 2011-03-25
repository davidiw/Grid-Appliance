#!/bin/bash
source /etc/ipop.vpn.config
IDIR=$DIR
source /etc/grid_appliance.config

paths=(/var/log /tmp /var/run $DIR/var $IDIR/var /root/.wapi)
files=($DIR/etc/condor_config.d/00root)
ipopfiles=(ipop.config bootstrap.config certificates/* dhcp.config node.config private_key dht_proxy)

apt-get clean

for path in ${paths[@]}; do
  for subpath in $(find $path); do
    rm -f $subpath/* $subpath/.* >- 2>-
  done
done

rm /root/.ssh/authorized_keys
if test -e /root/.ssh/authorized_keys.bak; then
  mv /root/.ssh/authorized_keys.bak /root/.ssh/authorized_keys
fi

for file in ${ipopfiles[@]}; do
  rm -f $IDIR/etc/$file >- 2>-
done

for file in ${files[@]}; do
  rm -f $file
done

touch /var/log/dmesg
touch /var/log/wtmp

for user in $(ls /home); do
  deluser --remove-all-files $user
done

touch $DIR/etc/not_configured
