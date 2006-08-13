dir="/usr/local/ipop"
init_dir="/etc/init.d"
rc2_dir="/etc/rc2.d"
rc3_dir="/etc/rc3.d"
user_dir="/home/griduser"

ln -sf $dir/scripts/cow.sh $init_dir/cow.sh
ln -sf $init_dir/cow.sh /etc/rcS.d/S11cow
ln -sf $dir/scripts/dns.sh $init_dir/dns.sh
ln -sf $init_dir/dns.sh $rc2_dir/S90dns
ln -sf $init_dir/dns.sh $rc3_dir/S90dns
ln -sf $dir/scripts/update_ipop.sh $init_dir/update_ipop.sh
ln -sf $init_dir/update_ipop.sh $rc2_dir/S91update_ipop
ln -sf $init_dir/update_ipop.sh $rc3_dir/S91update_ipop
ln -sf $dir/scripts/ipop.sh $init_dir/ipop.sh
ln -sf $init_dir/ipop.sh $rc2_dir/S92ipop
ln -sf $init_dir/ipop.sh $rc3_dir/S92ipop
ln -sf $dir/scripts/gridcndor.sh $init_dir/gridcndor.sh
ln -sf $init_dir/gridcndor.sh $rc2_dir/S93gridcndor
ln -sf $init_dir/gridcndor.sh $rc3_dir/S93gridcndor
ln -sf $dir/scripts/xison.sh $init_dir/xison.sh
ln -sf $init_dir/xison.sh $rc2_dir/S99xison
ln -sf $init_dir/xison.sh $rc3_dir/S99xison
ln -sf $dir/scripts/xen_grid.sh $init_dir/xen_grid.sh
ln -sf $init_dir/xen_grid.sh $rc3_dir/S99xen_grid

rm $rc3_dir/*vmware*

files=`ls -A $dir/griduser`
for file in $files; do
  ln -s -f $dir/griduser/$file $user_dir/$file
done

cp /etc/dhclient.conf $dir/config/dhclient.conf

echo "prepend domain-name-servers 127.0.0.1;" >> /etc/dhclient.conf
echo "supersede domain-name \"ipop\";" >> /etc/dhclient.conf