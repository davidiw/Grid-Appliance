#!/bin/bash
# This is the RC script for Grid-Appliance and performs the following functions
# 1) Check for a pre-existing configuration (grid_client_lastcall)
# 2a) If it does not exist, access the IPOP "DHCP" server and obtain an IP
#     address, condor configuration file, and finally generate /etc/hosts
# 2b) If it does exist, continue
# 3) Initialize the tap device
# 4) Start iprouter
# 5) Apply the iptables rules

dir="/usr/local/ipop"
System=`$dir/scripts/Env.sh`

if [[ $System = "linux" || $System = "xen0" || $System = "xenU" ]]; then
  if [[ $1 = "start" || $1 = "restart" ]]; then
    iptables -F
    if [[ $1 = start ]]; then
      echo "Starting Grid Services..."
    else
      echo "Restarting Grid Services..."
      if [[ $System = "linux" || $System = "xen0" ]]; then
        pkill iprouter 
      fi
    fi

    if [[ $System = "linux" || $System = "xen0" ]]; then
      # set up tap device
      $dir/tools/tunctl -u root -t tap0
      if [[ $System = "xen0" ]]; then
        brctl addbr xen-ipop
        brctl addif xen-ipop tap0
        ifconfig xen-ipop up
        ifconfig tap0 up
      fi


      echo "tap configuration completed"

      # Create config file for IPOP and start it up
      if test -f $dir/var/ipop.config; then
        test
      else
        if [[ $System = "linux" ]]; then
          cp $dir/config/ipop_dhcp_auto.config $dir/var/ipop.config
        elif [[ $System = "xen0" ]]; then
          cp $dir/config/ipop_dhcp_manual.config $dir/var/ipop.config
        fi
      fi

      cd $dir/tools
      $dir/tools/iprouter $dir/var/ipop.config $dir/config/log.config | /usr/bin/cronolog --period="1 day" --symlink=$dir/var/ipoplog $dir/var/ipop.log.%y%m%d &
      cd -

      rm -f /var/log/ipop
      ln -s $dir/var/ipoplog /var/log/ipop
    fi

    #disable this if you're going to using ipop_static
    if [[ $System = "linux" && ( $1 = "start" || $1 = "restart" ) ]]; then
      for pid in `ps uax | grep "dhclient tap0" | awk -F" " '{print $2}'`; do
      	kill $pid
      done
      dhclient tap0
    elif [[ $System = "xenU" ]]; then
      hostname="C"
      ip=`ifconfig eth0 | awk -F"inet addr:" '{print $2}' | awk -F"  Bcast:" '{print $1}'`
      for (( i = 2; i < 5; i++ )); do
        temp=`echo $ip | awk -F"." '{print $'$i'}' | awk -F"." '{print $1}'`
        if (( $temp < 10 )); then
          hostname=$hostname"00"
        elif (( $temp < 100 )); then
          hostname=$hostname"0"
        fi
        hostname=$hostname$temp
      done
      hostname $hostname
      ifconfig eth0 mtu 1500
    fi

    echo "IPOP has started"
    # Geo locator
    iptables -F
    latitude=`wget www.ip-adress.com -q -O - | grep latitude -A 1 | grep td | awk -F">" '{print $3}' | awk -F"<" '{print $1}'`
    longitude=`wget www.ip-adress.com -q -O - | grep longitude -A 1 | grep td | awk -F">" '{print $3}' | awk -F"<" '{print $1}'`
    echo $latitude", "$longitude > /home/griduser/.geo
    # Applying iprules
    $dir/scripts/iprules

  elif [[ $1 = "stop" ]]; then
    if [[ $System = "linux" || $System = "xen0" ]]; then
      pkill iprouter
      ifdown tap0
      $dir/tools/tunctl -d tap0
    fi
  else
    echo "Run script with start, restart, or stop"
  fi
fi
