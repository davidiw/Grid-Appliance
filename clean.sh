#!/bin/bash

rm -f /root/client/var/* \
/home/condor/condor/home/log/* \
/var/log/* \
/home/condor/condor/home/spool/* \
/home/condor/.xison \
/home/condor/.xdisabled

echo "Reset condor password to password" 
passwd condor
passwd -e condor
