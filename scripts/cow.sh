#!/bin/bash
dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`
VMM=`$dir/scripts/vmm.sh`
release=`$dir/scripts/release_check.sh`
if [[ $1 = "start" ]]; then
  if [[ $VMM = "vmware" || $VMM = "xenU" ]]; then
    drive_prefix="s"
  else
    drive_prefix="h"
  fi

  if [[ $System = "linux" || $System = "xenU" ]]; then
    if [ $release == "yes" ]; then
      mount -text3 /dev/"$drive_prefix"dc1 /.unionfs
      mkdir /.unionfs/.unionfs
      mount -text3 /dev/"$drive_prefix"dd1 /.unionfs/.unionfs
      dirs=`ls /`
      for dir in $dirs; do
        if [[ -d "/$dir" && $dir != "proc" && $dir != "sys" ]]; then
          mkdir /.unionfs/$dir &> /dev/null
          mkdir /.unionfs/.unionfs/$dir &> /dev/null
          if [[ $dir = "tmp" ]]; then
            chmod 777 /.unionfs/.unionfs/$dir &> /dev/null
          else
            chmod 755 /.unionfs/.unionfs/$dir &> /dev/null
          fi
          mount -t unionfs -odefaults,dirs=/.unionfs/.unionfs/$dir=rw:/.unionfs/$dir=ro:/$dir=ro none /$dir
        fi
      done
    else
      mount -text3 /dev/"$drive_prefix"dc1 /.unionfs
      dirs=`ls /`
      for dir in $dirs; do
        if [[ -d "/$dir" && $dir != "proc" && $dir != "sys" ]]; then
          mkdir /.unionfs/$dir &> /dev/null
          if [[ $dir = "tmp" ]]; then
            chmod 777 /.unionfs/$dir &> /dev/null
          else
            chmod 755 /.unionfs/$dir &> /dev/null
          fi
          mount -t unionfs -odefaults,dirs=/.unionfs/$dir=rw:/$dir=ro none /$dir
        fi
      done
    fi
  fi
fi
