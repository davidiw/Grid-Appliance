#!/bin/bash
dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`


if [[ $System = "linux" || $System = "xen0" ]]; then
  #Checks to see if there is a newer version of iprouter available
  if [[ $1 != "start" ]]; then
    sleeptime=`expr $RANDOM \* 120`
    sleeptime=`expr $sleeptime % 7200`
    sleep $sleeptime
  fi

  iptables -F

  echo "Checking for latest version of iprouter"
  wget http://www.acis.ufl.edu/~ipop/ipop/iprouter_current.txt -O $dir/var/iprouter_current.txt
  if test -f $dir/var/iprouter_current.txt; then
    web_version=`cat $dir/var/iprouter_current.txt`
  else
    web_version=-1
  fi
  local_version=`cat $dir/etc/iprouter_current.txt`
  if (( web_version > local_version)); then
    echo "New version found!  Updating..."
    wget http://www.acis.ufl.edu/~ipop/ipop/iprouter.bz2 -O $dir/var/iprouter.bz2
    bunzip2 $dir/var/iprouter.bz2
    mv -f $dir/var/iprouter $dir/tools/iprouter
    chmod +x $dir/tools/iprouter
    mv $dir/var/iprouter_current.txt $dir/etc/iprouter_current.txt
    if [[ $1 != "start" ]]; then
      $dir/scripts/ipop.sh stop
      $dir/scripts/ipop.sh start
    fi
  else
    echo "Current version is up to date!"
    rm $dir/var/iprouter_current.txt
  fi
  echo "iprouter update complete"
fi