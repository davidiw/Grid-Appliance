#This file is not up to date

dir="/usr/local/ipop"
init_dir="/etc/init.d"
rc2_dir="/etc/rc2.d"
user_dir="/home/griduser"

ln -sf $dir/scripts/cow.sh $init_dir/cow.sh
ln -sf $init_dir/cow.sh /etc/rcS.d/S11cow
ln -sf $dir/scripts/dns.sh $init_dir/dns.sh
ln -sf $init_dir/dns.sh $rc2_dir/S90dns
ln -sf $dir/scripts/update_ipop.sh $init_dir/update_ipop.sh
ln -sf $init_dir/update_ipop.sh /etc/rcS.d/S42update_ipop
ln -sf $dir/scripts/ipop.sh $init_dir/ipop.sh
ln -sf $init_dir/ipop.sh /etc/rcS.d/S39ipop
ln -sf $dir/scripts/gridcndor.sh $init_dir/gridcndor.sh
ln -sf $init_dir/gridcndor.sh $rc2_dir/S93gridcndor
ln -sf $dir/scripts/enable_admin_ssh.sh $init_dir/enable_admin_ssh
ln -sf $init_dir/enable_admin_ssh /etc/rc2.d/S93enable_admin_ssh
ln -sf $dir/scripts/xison.sh $init_dir/xison.sh
ln -sf $init_dir/xison.sh $rc2_dir/S99xison

files=`ls -A $dir/griduser`
for file in $files; do
  ln -s -f $dir/griduser/$file $user_dir/$file
done

echo "prepend domain-name-servers 127.0.0.1;" >> /etc/dhclient.conf
echo "supersede domain-name \"ipop\";" >> /etc/dhclient.conf
echo "auto tap0" >> /etc/network/intefaces
echo "iface tap0 inet dhcp" >> /etc/network/interfaces
