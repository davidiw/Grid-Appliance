#!/bin/bash
#mounts dht shared folders (experimental)
dir="/usr/local/ipop"

key=$1
host=`$dir/scripts/DhtHelper.py get $key`
echo "-fstype=nfs,ro,nolock $host:/mnt/local" 
