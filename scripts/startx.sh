#!/bin/bash

### BEGIN INIT INFO
# Provides:          startx
# Required-Start:
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:       
# X-Start-Before:   
# Short-Description: Starts Xorg for Client
# Description:       Starts Xorg for Client
### END INIT INFO

source /etc/grid_appliance.config
source /etc/group_appliance.config

if [[ $MACHINE_TYPE == "Client" && "`which startx`" ]]; then
  if [[ ! `$DIR/scripts/utils.sh get_pid X` ]]; then
    if ! test -d /home/$CONDOR_USER; then
      $DIR/scripts/adduser.sh $CONDOR_USER
    fi
    sudo -i -b -u $CONDOR_USER 'startx' &> /var/log/startx.log
  fi
fi
