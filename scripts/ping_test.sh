#!/bin/bash

if ! `$dir/scripts/utils.sh check_fd`; then
  exit
fi

manager_ip=`cat $dir/etc/manager_ip`
/opt/condor/bin/condor_status | awk /^C/ | awk -F. '{print $1}' > /tmp/cndor

echo $manager_ip >> /tmp/cndor
echo "Starting new session" >> /usr/local/ipop/var/ping.log
date >> /usr/local/ipop/var/ping.log
for node in `cat /tmp/cndor`; do
  ping $node -c 3 -W 30 >> /usr/local/ipop/var/ping.log
done
date >> /usr/local/ipop/var/ping.log
echo "Done with ping test" >> /usr/local/ipop/var/ping.log
