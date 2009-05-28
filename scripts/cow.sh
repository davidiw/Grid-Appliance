#!/bin/bash
dir="/usr/local/ipop"
release=`$dir/scripts/utils.sh check_release`
#aufs or unionfs
fs="aufs"

if [ $1 == "start" ]; then
  if test -e /dev/sda1; then
    drive_prefix="s"
    drive=(a b c d)
  else
    drive_prefix="h"
    drive=(a b d)
  fi

  new_root=/.root
  old_root=.oldroot

  dev_path="/.unionfs"
  dev=$dev_path"=rw"
  base_path=$dev_path
  home=""
  mount -text3 /dev/"$drive_prefix"d"${drive[1]}"1 $dev_path

  if [ $release == "yes" ] ; then
    home_path=$dev_path"/.unionfs"
    home=$home_path"=rw:"
    base_path=$home_path
    dev=$dev_path"=ro"
    mkdir $base_path &> /dev/null
    mount -text3 /dev/"$drive_prefix"d"${drive[2]}"1  $base_path
  fi

  if [ $fs == "aufs" ]; then
    rm -rf $base_path/.tmp &> /dev/null
    mkdir $base_path/.tmp &> /dev/null
  fi

  mount -n -t $fs -odefaults,dirs=$home$dev:/=ro none $new_root 
  cd $new_root
  pivot_root . $old_root
  mount --move /$old_root/$dev_path $dev_path
  if [ "$rel_path" ]; then
    mount --move /$old_root/$home_path $home_path
  fi

  mount -n -t proc none /proc
  cat /proc/mounts > /etc/mtab
  umount /proc

  mkdir -p $base_path/mnt/local &> /dev/null
  mount --bind $base_path/mnt/local /mnt/local &> /dev/null
  chown -R griduser:griduser $base_path/mnt/local &> /dev/null
    
  echo "Mounting CoW complete"
fi
