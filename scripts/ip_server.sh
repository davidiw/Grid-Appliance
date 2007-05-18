#!/bin/bash
dir="/usr/local/ipop"

if [[ $1 = "start" ]]; then
  route add -net 224.0.0.0 netmask 240.0.0.0 dev eth1
  cd $dir/tools/
  mono $dir/tools/server.exe &> /dev/null &
  cd -
fi
