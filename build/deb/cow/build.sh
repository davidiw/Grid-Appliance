#!/bin/bash
if [[ ! "$1" ]]; then
  echo "Usage: base_install.sh version"
  exit
fi

package_dir=grid_appliance_cow
version=$1

debian_dir=$package_dir"/DEBIAN"
mkdir -p $debian_dir
for file in control prerm postinst; do
  cp $file $debian_dir/.
done
echo "Version: $version" >> $package_dir/DEBIAN/control

dpkg-deb -b $package_dir
rm -rf $package_dir
mv $package_dir.deb $package_dir"_"$version".deb"
