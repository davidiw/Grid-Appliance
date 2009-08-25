#!/bin/bash
#mounts dht shared folders (experimental)
source /etc/grid_appliance.config

key=$1
host=`$DIR/scripts/DhtHelper.py get $key`
echo "-fstype=nfs,ro,nolock $host:/mnt/local" 
