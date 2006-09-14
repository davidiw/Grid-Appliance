#!/bin/bash
dir="/usr/local/ipop"

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
$dir/var/* \
/root/.wapi/* \
/tmp/.*

echo "Reset griduser password to password" 
passwd griduser 
passwd -e griduser 
