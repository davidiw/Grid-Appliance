#!/bin/bash
#Checks to see if there is a newer version of iprouter available

iptables -F

echo "Checking for latest version of iprouter"
wget http://www.acis.ufl.edu/~ipop/ipop/iprouter_current.txt -O /root/client/var/iprouter_current.txt
if test -f /root/client/var/iprouter_current.txt; then
  web_version=`cat /root/client/var/iprouter_current.txt`
else
  web_version=-1
fi
local_version=`cat /root/client/etc/iprouter_current.txt`
if (( web_version > local_version)); then
  echo "New version found!  Updating..."
  wget http://www.acis.ufl.edu/~ipop/ipop/iprouter.bz2 -O /root/client/var/iprouter.bz2
  bunzip2 /root/client/iprouter.bz2
  mv /root/client/var/iprouter /root/tools/iprouter
  chmod +x /root/tools/iprouter
  mv /root/client/var/current.txt /root/client/etc/iprouter_current.txt
  if [[ $1 != "start" ]]; then
    /etc/init.d/ipop stop
    /etc/init.d/ipop start
  fi
else
  echo "Current version is up to date!"
  rm /root/client/var/iprouter_current.txt
fi
echo "iprouter update complete"
