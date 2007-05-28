#!/bin/bash
dir="/usr/local/ipop"

if [[ `cat $dir/etc/condor_type` = "manager" ]]; then
  if [[ $1 = "start" ]]; then
    cd $dir/tools/
    mono $dir/tools/SimpleNode.exe -c $dir/var/dhtif.conf -df $dir/var/dhtdata.conf &> /dev/null &
    cd -
  fi
fi
