#!/bin/bash
#PACKAGE_DIR is used for creating a Debian / Ubuntu package and has no effect
#when it is not instantiated

if [[ ! $PACKAGE_DIR ]]; then
  if [[ ! -e `which tunctl 2> /dev/null` ]]; then
    echo "Missing tunctl -- install uml-utilities"
    exit
  elif [[ ! -e `which mono 2> /dev/null` ]]; then
    echo "Missing mono -- install mono"
    exit
  elif [[ ! -e `which cronolog 2> /dev/null` ]]; then
    echo "Missing cronolog -- install cronolog"
    exit
  elif [[ ! -e `which python 2> /dev/null` ]]; then
    echo "Missing python -- install python"
    exit
  fi
fi

path=`which $0`
path=`dirname $path`

mkdir -p $PACKAGE_DIR/opt/grid_appliance
for i in etc scripts tests; do
  cp -axf $path/$i $PACKAGE_DIR/opt/grid_appliance/.
done
mkdir -p $PACKAGE_DIR/opt/grid_appliance/etc/condor_config.d

mkdir -p $PACKAGE_DIR/home
cp -axf $path/griduser $PACKAGE_DIR/home

mkdir -p $PACKAGE_DIR/etc/init.d
cd $PACKAGE_DIR/etc/init.d
for i in cow.sh ipop.sh startup.sh mount_fd.sh; do
  ln -sf ../../opt/grid_appliance/scripts/$i .
done
cd  - &> /dev/null

mkdir -p $PACKAGE_DIR/etc/rcS.d
cd $PACKAGE_DIR/etc/rcS.d
ln -sf ../init.d/cow.sh S00cow
ln -sf ../init.d/mount_fd.sh S40mount_fd
ln -sf ../init.d/ipop.sh S41ipop
cd  - &> /dev/null

for i in 2 3 4 5; do
  mkdir -p $PACKAGE_DIR/etc/rc$i.d
  cd $PACKAGE_DIR/etc/rc$i.d
  ln -sf ../init.d/startup.sh S99startup
  cd  - &> /dev/null
done

mkdir -p $PACKAGE_DIR/etc
cd $PACKAGE_DIR/etc
for i in ipop.vpn.config grid_appliance.config exports auto.master issue; do
  ln -sf ../opt/grid_appliance/etc/$i .
done
ln -sf ../opt/grid_appliance/var/group_appliance.config .
cd - &> /dev/null

mkdir -p $PACKAGE_DIR/etc/condor
cd $PACKAGE_DIR/etc/condor
ln -sf ../../opt/grid_appliance/etc/condor_config .
ln -sf ../../opt/grid_appliance/scripts/condor_config.sh .
cd - &> /dev/null

mkdir -p $PACKAGE_DIR/etc/autofs
cd $PACKAGE_DIR/etc/autofs
for i in dht_nfs_automount.sh nfs_automount.sh; do
  ln -sf ../../opt/grid_appliance/scripts/$i .
done
cd - &> /dev/null

mkdir -p $PACKAGE_DIR/opt/grid_appliance/var

source $path/etc/ipop.vpn.config
mkdir -p $PACKAGE_DIR/$DIR/bin
cp $path/tools/Brunet.Inject.HostActivity.dll $PACKAGE_DIR/$DIR/bin

if [[ ! $PACKAGE_DIR ]]; then
  echo "Done installing GridAppliance"
fi
