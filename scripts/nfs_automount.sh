#!/bin/bash
#mounts remote ganfs based upon hostname
host=$1
echo "-fstype=nfs,ro,nolock $host:/mnt/local" 
