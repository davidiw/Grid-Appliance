#!/bin/bash
# This is the RC script for Grid-Appliance and performs the following functions
# 1) Check for a pre-existing configuration (grid_client_lastcall)
# 2a) If it does not exist, access the IPOP "DHCP" server and obtain an IP
#     address, condor configuration file, and finally generate /etc/hosts
# 2b) If it does exist, continue
# 3) Initialize the tap device
# 4) Start iprouter
# 5) Apply the iptables rules

if [[ $1 = "start" || $1 = "restart" ]]
  then
  iptables -F
  if test ! -f /root/client/var/grid_client_lastcall
    then
    echo "Starting a new Grid machine..."
    /root/client/ipop_dhcp.py

    # Write the /etc/hosts file
    echo "127.0.0.1 localhost.localdomain localhost grid" > /etc/hosts

    echo "Generating /etc/hosts..."
    count=1
    start=`cat /root/client/var/grid_client_lastcall | tr "." ":" | awk -F : '{ print $2 }'`
    end=`expr $start + 2`
    for (( i = start; i < end; i++ ))
    do
      if (( i < 10 )); then
        istr="00$i"
      elif (( i < 100 )); then
        istr="0$i"
      else
        istr=$i
      fi
      for (( j = 0; j <= 255; j++ ))
      do
        if (( j < 10 )); then
          jstr="00$j"
        elif (( j < 100 )); then
          jstr="0$j"
        else
          jstr=$j
        fi
        for (( k = 1; k < 255; k++ ))
        do
          if (( k < 10 )); then
            kstr="00$k"
          elif (( k < 100 )); then
            kstr="0$k"
          else
            kstr=$k
          fi
          if (( k == 2 )); then
            echo "10.$i.$j.$k manager$count manager$count" >> /etc/hosts
          else
            echo "10.$i.$j.$k c$istr$jstr$kstr c$istr$jstr$kstr" >> /etc/hosts
          fi
        done
        count=`expr $count + 1`
      done
    done

    echo "::1      ip6-localhost    ip6-loopback" >> /etc/hosts
    echo "fe00::0  ip6-localnet" >> /etc/hosts
    echo "fe00::0  ip6-mcastprefix" >> /etc/hosts
    echo "ff02::1  ip6-allnodes" >> /etc/hosts
    echo "ff02::2  ip6-allrouters" >> /etc/hosts
    echo "ff02::3  ip6-allhosts" >> /etc/hosts

    # End /etc/hosts generation

    # Generate the /etc/hosts and copies to proper place 
    ip=`cat /root/client/var/grid_client_lastcall|awk -F : '{print $1}'`
    hostname=`cat /root/client/var/grid_client_lastcall|awk -F : '{print $2}'`

    tar -zxf /root/client/config.tar.gz -C /root/client

    # copy the condor configuration file to /home/condor
    cp /root/client/client.$ip/condor_config.$ip /home/condor/condor_config
    echo "condor_config.$ip copied to proper location"
    cp /root/client/client.$ip/iprules /root/client/iprules

    # Deleting configuration files
    rm /root/client/config.tar.gz
    rm -R /root/client/client.$ip
  elif [[ $1 = start ]]; then
    echo "Resuming a previous Grid machine..."
  else
    echo "Restarting Grid services..."
    pkill iprouter 
  fi

  # Generate the /etc/hosts and copies to proper place 
  ip=`cat /root/client/var/grid_client_lastcall|awk -F : '{print $1}'`
  hostname=`cat /root/client/var/grid_client_lastcall|awk -F : '{print $2}'`

  # Clear the existing log
  /bin/rm /var/log/ipop

  # Tap configuration
  hostname $hostname

  # set up tap device and routes
  ifconfig tap0 down
  /root/tools/tunctl -u root -t tap0
  ifconfig tap0 up $ip
  ifconfig tap0 mtu 1350
  route add -net 10.128.0.0 netmask 255.128.0.0 gw 10.128.0.1 tap0
  arp -s 10.128.0.1 FE:FD:00:00:00:00
  route del -net 10.0.0.0 netmask 255.0.0.0

  echo "tap configuration completed"

  # Create config file for IPOP and start it up
  /sbin/ifconfig tap0|head -1|awk '{print $5}' > /root/client/var/tap0mac
  /bin/cp /root/client/ipop.config /root/client/var/ipop.config.$ip
  echo $ip >> /root/client/var/ipop.config.$ip
  cat /root/client/var/tap0mac >> /root/client/var/ipop.config.$ip
  /root/tools/iprouter /root/client/var/ipop.config.$ip &> /root/client/var/ipoplog.$ip &

  echo "IPOP has started"

  # Applying iprules
  /root/client/iprules

  # Link to the new log
  /bin/ln -s /root/client/var/ipoplog.$ip /var/log/ipop
elif [ $1 = "stop" ]; then
  route del -net 10.128.0.0 netmask 255.128.0.0
  ifdown tap0
  pkill iprouter
  /root/tools/tunctl -d tap0
else
  echo "Run script with start, restart, or stop"
fi
