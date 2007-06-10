#!/bin/bash
#This script runs on the first boot and allows the user to create his own WOW.
#Expect major changes to this script as the system evolves!

dir="/usr/local/ipop"
release=`$dir/scripts/utils.sh check_release`

if `$dir/scripts/utils.sh check_fd`; then
  exit
fi

device="/dev/fd0"

echo "Welcome to the Grid Appliance system setup!"
echo "This program will help you setup your own grid appliance cluster.  Please"
echo "follow the on-screen instructions."
echo

ns_correct="no"
while [[ $ns_correct = "no" ]]; do
  echo "Please enter an IPOP namespace: "
  read -e ipop_ns
  correct=""
  while [[ $correct != "yes" && $correct != "no" ]]; do
    echo "You entered " $ipop_ns " is this correct?  Enter yes or no."
    read -e correct
  done
  if [[ $correct = "yes" ]]; then
    cp -af $dir/etc/ipop.config $dir/var/dhtif.conf
    echo "key=dhcp:ipop_namespace:"$ipop_ns > $dir/var/dhcpdata.conf
    echo "ttl=302400" >> $dir/var/dhcpdata.conf
    echo "value=<IPOPNamespace><value>"$ipop_ns"</value><netmask>255.192.0.0</netmask><pool><lower>10.128.0.0</lower><upper>10.191.255.255</upper></pool><reserved><value><DHCPReservedIP><ip>0.0.0.1</ip><mask>0.0.0.255</mask></DHCPReservedIP></value></reserved><leasetime>604800</leasetime><LogSize>20480</LogSize></IPOPNamespace>" >> $dir/var/dhcpdata.conf
    echo "Waiting on creation process"
    cd $dir/tools
    result=`mono $dir/tools/SimpleNode.exe -c $dir/var/dhtif.conf -df one_run $dir/var/dhcpdata.conf 2> /dev/null`
    cd -
    if [[ $result = "Pass" ]]; then
      ns_correct=$correct
    fi
  fi
done

echo "manager" > $dir/etc/condor_type

#create floppy and get condor manager ip
umount /mnt/fd &> /dev/null
mkfs.ext2 -m0 $device &> /dev/null
mount $device /mnt/fd &> /dev/null
echo $ipop_ns > /mnt/fd/ipop_ns
cp $dir/var/dhcpdata.conf /mnt/fd/dhcpdata.conf

echo "Starting Virtual Network to obtain the rest of the configuration information."
$dir/scripts/ipop.sh start &> /dev/null
dhclient tap0 &> /dev/null

tap_ip=`$dir/scripts/utils.sh get_ip tap0`
while [[ tap_ip = "" ]]; do
  sleep 10
  tap_ip=`$dir/scripts/utils.sh get_ip tap0`
done

echo "This node will be the condor manager:  "$tap_ip
echo

echo $tap_ip > /mnt/fd/condor_manager
umount /mnt/fd &> /dev/null
#tell user how to access floppy disk
echo "Your floppy image is now available the virtual machine will automatically"
echo "shutdown.  Please retrieve the master image (fdb.img) from the directory"
echo "that contains the virtual machine"
echo "contains the "
echo "virtual machine."
echo
echo "Press any key to procede to shutdown"
read
halt
