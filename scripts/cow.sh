#!/bin/bash
dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`

if [[ $System = "linux" || $System = "xenU" ]]; then
  release=`cat /proc/1/environ | tr "\0" ":" | awk -F"release=" '{print $2}'`
  release=$release:
  release=`echo $release | awk -F":" '{print $1}'`
  if [ $release == "yes" ]; then
    mount -text3 /dev/sdc1 /.unionfs
    mkdir /.unionfs/.unionfs
    mount -text3 /dev/sdd1 /.unionfs/.unionfs
    dirs=`ls /`
    for dir in $dirs; do
      if [[ -d "/$dir" && $dir != "proc" && $dir != "sys" && $dir != "dev" ]]; then
        mkdir /.unionfs/$dir &> /dev/null
        mkdir /.unionfs/.unionfs/$dir &> /dev/null
        if [[ $dir = "tmp" ]]; then
          chmod 777 /.unionfs/.unionfs/$dir &> /dev/null
        else
          chmod 755 /.unionfs/.unionfs/$dir &> /dev/null
        fi
        mount -t unionfs -odefaults,dirs=/.unionfs/.unionfs/$dir:/.unionfs/$dir=r0:/$dir=ro none /$dir
      fi
    done
  else
    mount -text3 /dev/sdc1 /.unionfs
    dirs=`ls /`
    for dir in $dirs; do
      if [[ -d "/$dir" && $dir != "proc" && $dir != "sys" && $dir != "dev" ]]; then
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