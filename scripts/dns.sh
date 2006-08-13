#!/bin/bash
dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`

if [[ $System != "linux" || $System != "xenU" ]]; then
  python $dir/scripts/dns.py &
fi
