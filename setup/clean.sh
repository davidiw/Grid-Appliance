#!/bin/bash

rm -f /root/client/var/* \
/opt/condor/var/* \
/opt/condor/var/*/* \
/opt/condor/var/*/.* \
/var/log/* \
/var/log/*/* \
/var/log/*/*/* \
/home/griduser/.xison \
/home/griduser/.xdisabled \
/etc/condor/condor_config \
/root/client/var/*

echo "Reset griduser password to password" 
passwd griduser 
passwd -e griduser 
