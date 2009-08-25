#!/bin/bash
source /etc/grid_appliance.config

path=$DIR"/etc/condor_config.d/"
for i in `ls $path`; do
  if test -f $path"/"$i; then
    cat $path"/"$i
  fi
done
