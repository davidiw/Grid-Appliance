#!/bin/bash
if [[ ! "$1" ]]; then
  echo "Usage: base_install.sh version"
  exit
fi

path="../../.."
package_dir=grid_appliance
source $path/etc/grid_appliance.config
version=$1

mkdir -p $package_dir/$DIR
for i in etc scripts tests tools; do
  cp -axf $path/$i $package_dir/$DIR
done

mkdir -p $package_dir/etc/init.d
cd $package_dir/etc/init.d
for i in cow.sh grid_appliance.sh; do
  ln -sf ../../$DIR/scripts/$i .
done
cd  - &> /dev/null

cd $package_dir/etc
ln -sf ../$DIR/var/group_appliance.config .
ln -sf ../$DIR/etc/grid_appliance.config .
cd - &> /dev/null

mkdir -p $package_dir/$DIR/var

debian_dir=$package_dir"/DEBIAN"
mkdir -p $debian_dir
for file in control prerm postinst; do
  cp $file $debian_dir/.
done
echo "Version: $version" >> $package_dir/DEBIAN/control

dpkg-deb -b $package_dir
rm -rf $package_dir
mv $package_dir.deb $package_dir"_"$version".deb"
