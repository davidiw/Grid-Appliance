#!/bin/bash
dir="/usr/local/ipop"

rm -f /usr/local/ipop/var/* \
/opt/condor/var/* \
/opt/condor/var/*/* \
/opt/condor/var/*/.* \
/var/log/* \
/var/log/*/* \
/var/log/*/*/* \
/home/griduser/.xison \
/home/griduser/.xdisabled \
/etc/condor/condor_config \
/root/.wapi/* \
/tmp/.* \
/tmp/* \
/var/cache/apt/archives/*deb \
/var/run/* \
/var/run/*/* \
/var/lib/apt/* \
/var/lib/apt/*/*


echo "Reset griduser password to password" 
passwd griduser 
passwd -e griduser 
