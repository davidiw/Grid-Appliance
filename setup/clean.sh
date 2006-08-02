#!/bin/bash

rm -f /root/client/var/* \
/home/condor/condor/home/log/* \
/var/log/* \
/home/condor/condor/home/spool/* \
/home/condor/.xison \
/home/condor/.xdisabled \
/home/condor/condor/etc/condor_config \
/home/condor/condor_config

echo "Reset condor password to password" 
passwd condor
passwd -e condor
