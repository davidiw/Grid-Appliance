#!/bin/bash

dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`

if [[ $System = "xen0" ]]; then
  xend start
  xm create /usr/local/ipop/config/condor_xen -c
fi