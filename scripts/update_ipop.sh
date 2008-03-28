#!/bin/bash
dir="/usr/local/ipop"

run()
{
  echo "Checking for latest version for Grid Appliance."
  url=`cat /mnt/fd/update_url`
  wget $url/current.txt -O $dir/var/current.txt &> /dev/null
  if test -f $dir/var/current.txt; then
    web_version=`cat $dir/var/current.txt`
  else
    web_version=-1
  fi
  local_version=`cat $dir/etc/current.txt`
  rm $dir/var/current.txt
  if (( web_version <= local_version )); then
    echo "Current version is up to date!"
    exit
  fi

  echo "New version $web_version found!  Updating..."
  #Checks to see if there is a newer version of iprouter available
  if [[ $1 == "cron" ]]; then
    sleeptime=`expr $RANDOM \* 120`
    sleeptime=`expr $sleeptime % 18`
    echo "Sleeping for $sleeptime then applying update."
    sleep $sleeptime
  fi

  wget $url/ipop.deb -O $dir/var/ipop.deb &> /dev/null
  dpkg --install $dir/var/ipop.deb
  rm -f $dir/var/ipop.deb &> /dev/null
  echo "Installation Complete!"
}

if [[ $1 && $1 == "cron" ]]; then
  run 2>1 | logger -t ipop
else
  run
fi