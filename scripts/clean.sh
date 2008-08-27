#!/bin/bash
dir="/usr/local/ipop"

paths="opt/condor/var
var/log
tmp
var/run
var/lib/apt
usr/local/ipop/var
etc/condor
root/.wapi
"

for k in "/.unionfs/.unionfs" "/.unionfs" "/"; do
  for i in $paths; do
    for j in `find $i`; do
      rm -f $k/$j/* &> /dev/null
      rm -f $k/$j/.* &> /dev/null
  done
  rm -f $k/home/griduser/.xison \
  $k/home/griduser/.xdisabled \
  $k/var/cache/apt/archives/*deb &> /dev/null

  if [[ k != "/" ]]; then
    rm -f $k/home/griduser/.Xauthority &> /dev/null
  fi
done

touch /var/log/dmesg
touch /var/log/wtmp
