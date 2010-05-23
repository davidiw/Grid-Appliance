#!/bin/bash
source /etc/ipop.vpn.config
IDIR=$DIR
source /etc/grid_appliance.config

paths=(var/log tmp var/run $DIR/var $IDIR/var root/.wapi root/.ssh)
files=($DIR/etc/condor_config.d/00root)
ipopfiles=(ipop.config bootstrap.config certificates/* dhcp.config node.config private_key)

dirs=("/")

if [[ `mount | grep '/.oldroot/tmp/opt'` ]]; then
  dirs=({$dirs[@]} "/.oldroot/tmp/opt")
fi

if [[ `mount | grep '/.oldroot/tmp/home'` ]]; then
  dirs=({$dirs[@]} "/.oldroot/tmp/home")
fi

apt-get clean

for base in ${dirs[@]}; do
  for dir in ${paths[@]}; do
    for fullpath in `find $base/$dir`; do
      rm -f $fullpath/* $fullpath/.* >- 2>-
    done
  done

  for file in ${ipopfiles[@]}; do
    rm -f $base/$IDIR/etc/$file >- 2>-
  done

  for file in ${files[@]}; do
    rm -f $base/$file
  done

  rm $base/var/log/* >- 2>-
  rm $base/var/log/*/* >- 2>-
  rm $base/var/log/*/*/* >- 2>-

  touch $base/var/log/dmesg
  touch $base/var/log/wtmp
done

for user in `ls /home`; do
  deluser $user
done

touch $DIR/etc/not_configured
