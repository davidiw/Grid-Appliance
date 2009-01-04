#!/bin/bash
dir="/usr/local/ipop"

path=$dir"/etc/condor_config.d/"
for i in `ls $path`; do
  if test -f $path"/"$i; then
    cat $path"/"$i
  fi
done
