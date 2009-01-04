#!/bin/bash
dir="/usr/local/ipop"
VMM=`$dir/scripts/utils.sh vmm`
release=`$dir/scripts/utils.sh check_release`
#aufs or unionfs
fs="aufs"

if [ $1 == "start" ]; then
  if [ $VMM == "vmware" ]; then
    drive_prefix="s"

  else
    drive_prefix="h"
  fi

  dev_path="/.unionfs"
  base_path=$dev_path
  mount -text3 /dev/"$drive_prefix"db1 $dev_path

  if [ $release == "yes" ] ; then
    rel_path=$dev_path"/.unionfs"
    base_path=$rel_path
    mkdir $rel_path &> /dev/null
    mount -text3 /dev/"$drive_prefix"dc1  $rel_path
  fi

  if [ $fs == "aufs" ]; then
    rm -rf $base_path/.tmp &> /dev/null
    mkdir $base_path/.tmp &> /dev/null
  fi

  dirs=`ls /`

  for dir in $dirs; do
    if [[ ! -d "/$dir" || $dir == "proc" || $dir == "sys" || $dir == "lost+found" ]]; then
      continue
    fi

    mkdir $dev_path/$dir &> /dev/null
    if [ $release == "yes" ]; then
      mkdir $rel_path/$dir &> /dev/null
    fi

    if [ $dir == "tmp" ]; then
      chmod 777 $base_path/$dir &> /dev/null
    else
      chmod 755 $base_path/$dir &> /dev/null
    fi

    if [ $dir == "mnt" ]; then
      mount --bind $base_path/$dir /$dir
      mkdir /mnt/local &> /dev/null
      if test -e /dev/sdd1; then
        mount /dev/sdd1 /mnt/local
      fi
      chown -R griduser:griduser /mnt/local
      mkdir /mnt/ganfs &> /dev/null
      mkdir /mnt/dhtnfs &> /dev/null
    else
      dev="$dev_path/$dir"
      home=""
      if [ $release == "yes" ]; then
        home="$rel_path/$dir=rw:"
        dev="$dev=ro"
      else
        dev="$dev=rw"
      fi

      mount -t $fs -odefaults,dirs=$home$dev:/$dir=ro none /$dir &> /dev/null
    fi
  done

  cat /proc/mounts > /etc/mtab
  rm -f /etc/mtab~*
fi

echo "Mounting CoW complete"
