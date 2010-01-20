#!/bin/bash
# This is used to check whether or not condor got configured properly
source /etc/ipop.vpn.config
source /etc/grid_appliance.config
config=$DIR"/etc/condor_config.d/00root"
fail=0
if [ ! -e $config ]; then
  echo "condor_config missing"
  echo "Failures may not be related to Condor, please run the IPOP test."
  exit
fi

res=`grep CONDOR_HOST $config | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"`
if [[ -z "$res" ]]; then
  fail=1
  echo "no CONDOR_HOST defined!"
fi

res=`grep DAEMON_LIST $config | awk -F "=" {'print $2'}`
if [[ "$res" == "`echo $res | grep -E "[:space:]"`" ]]; then     
  res=""
fi
if [[ -z "$res" ]]; then
  fail=1
  echo "no DAEMON_LIST defined!"
fi

res=`grep FLOCK_TO $config | awk -F "= " {'print $2'}`
if [[ "$res" = "`echo $res | grep -E "[:space:]"`" ]]; then
  $res=""
fi
if [[ -z "$res" ]]; then
  fail=1
  echo "no FLOCK_TO defined!"
fi

res=`grep NETWORK_INTERFACE $config | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"`
if [[ -z "$res" ]]; then
  fail=1
  echo "no NETWORK_INTERFACE defined!"
elif [[ "$res" != "`$DIR/scripts/utils.sh get_ip $DEVICE`" ]]; then
  fail=1
  echo "NETWORK_INTERFACE incorrect: "$res" != "`$DIR/scripts/utils.sh get_ip tap0`"!"
fi

if [[ $fail = 1 ]]; then
  echo "Failures may not be related to Condor, please run the IPOP test."
fi
