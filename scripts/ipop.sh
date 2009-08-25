#!/bin/bash
source /etc/grid_appliance.config
action="restart"
if [[ "$1" ]]; then
  action=$1
fi

md5old=`md5sum $DIR/var/groupvpn.zip 2> /dev/null | awk '{print $1}'`
md5new=`md5sum $CONFIG_PATH/groupvpn.zip 2> /dev/null | awk '{print $1}'`
if [[ "$md5old" != "$md5new" ]]; then
  rm -f $DIR/var/groupvpn.zip
  for i in groupvpn.zip group_appliance.config; do
    cp $CONFIG_PATH/$i $DIR/var/.
  done
  groupvpn_prepare.sh $DIR/var/groupvpn.zip
fi


/etc/init.d/groupvpn.sh $action

$DIR/scripts/iprules
