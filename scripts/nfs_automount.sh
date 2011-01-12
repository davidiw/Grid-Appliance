#!/bin/bash
#mounts remote ganfs based upon hostname
host=$1
hostname=$(echo $host | grep -oE "^[^\.]+")
if [[ "$host" == 127.0.0.1 || "$host" == "localhost" || $hostname == "$(hostname)" ]]; then
  echo "-fstype=nfs,rw,nolock 127.0.0.1:/mnt/local"
else
  echo "-fstype=nfs,ro,nolock $host:/mnt/local" 
fi
