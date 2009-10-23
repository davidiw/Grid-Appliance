#!/bin/bash
if [[ ! "$1" ]]; then
  echo "Usage: base_install.sh version"
  exit
fi

path="../../.."
package_dir=grid_appliance
version=$1

mkdir -p $package_dir/opt/grid_appliance
for i in etc scripts tests; do
  cp -axf $path/$i $package_dir/opt/grid_appliance/.
done
mkdir -p $package_dir/opt/grid_appliance/etc/condor_config.d

mkdir -p $package_dir/etc/init.d
cd $package_dir/etc/init.d
for i in cow.sh ipop.sh startup.sh mount_fd.sh; do
  ln -sf ../../opt/grid_appliance/scripts/$i .
done
cd  - &> /dev/null

mkdir -p $package_dir/etc/rcS.d
cd $package_dir/etc/rcS.d
ln -sf ../init.d/ipop.sh S41ipop
cd  - &> /dev/null

for i in 2 3 4 5; do
  mkdir -p $package_dir/etc/rc$i.d
  cd $package_dir/etc/rc$i.d
  ln -sf ../init.d/startup.sh S99startup
  cd  - &> /dev/null
done

cd $package_dir/etc
ln -sf ../opt/grid_appliance/var/group_appliance.config .
cd - &> /dev/null

mkdir -p $package_dir/etc/condor
cd $package_dir/etc/condor
ln -sf ../../opt/grid_appliance/etc/condor_config .
ln -sf ../../opt/grid_appliance/scripts/condor_config.sh .
cd - &> /dev/null

mkdir -p $package_dir/opt/grid_appliance/var

source $path/etc/ipop.vpn.config
mkdir -p $package_dir/$DIR/bin
cp $path/tools/Brunet.Inject.HostActivity.dll $package_dir/$DIR/bin

debian_dir=$package_dir"/DEBIAN"
mkdir -p $debian_dir
for file in control prerm postinst; do
  cp $file $debian_dir/.
done
echo "Version: $version" >> $package_dir/DEBIAN/control

dpkg-deb -b $package_dir
rm -rf $package_dir
mv $package_dir.deb $package_dir"_"$version".deb"
