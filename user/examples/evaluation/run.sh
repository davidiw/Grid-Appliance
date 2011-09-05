#!/bin/bash
device=tapipop
if test -e nodes; then
  rm nodes
fi

for dir in logs err out; do
  if ! test -e $dir; then
    mkdir $dir
  fi
done

rm -f nodes
cp -f submit.base submit
for node in $(condor_status -long | grep StartdIpAddr | grep -v "$(/opt/grid_appliance/scripts/utils.sh get_ip $device):" | awk -F"\"" '{print $2}'); do
  echo $(echo $node | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+") >> nodes
  echo "Requirements = (TARGET.StartdIpAddr == \"$node\")" >> submit
  echo queue >> submit
done
