#!/bin/bash
dir="/usr/local/ipop"

paths="/opt/condor/var
/var/log
/tmp
/var/run
/var/lib/apt
/usr/local/ipop/var
/etc/condor
/root/.wapi
"
for i in $paths; do
  for j in `find $i`; do
    rm -f $j/* &> /dev/null
    rm -f $j/.* &> /dev/null
  done
done

rm -f /home/griduser/.xison \
/home/griduser/.xdisabled \
/var/cache/apt/archives/*deb
touch /var/log/dmesg
touch /var/log/wtmp
