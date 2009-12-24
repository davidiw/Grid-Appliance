#!/bin/bash

### BEGIN INIT INFO
# Provides:          cow-sendsigs
# Required-Start:
# Required-Stop:
# Default-Start:     2 3 4 5 6
# Default-Stop:       
# X-Start-Before:    mountkernfs
# Short-Description: COW Sendsigs
# Description:       Prevents unionfs-fuse from being killed by sendsigs on shutdown
### END INIT INFO

if [[ $1 == "start" ]]; then
  pid=`pgrep unionfs-fuse`
  if [[ ! "`grep $pid /var/run/sendsigs.omit`" ]]; then
    echo $pid > /var/run/sendsigs.omit
  fi
fi
