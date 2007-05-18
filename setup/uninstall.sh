#This file is not up to date

dir="/root/client/scripts"
init_dir="/etc/init.d"
rc_dir="/etc/rc2.d"
backup_dir="/root/client/config"

rm $iit_dir/SetEnv.sh /etc/rcS.d/S10SetEnv \
  $init_dir/cow.sh /etc/rcS.d/S11cow \
  $init_dir/dns.sh $rc_dir/S90dns \
  $init_dir/update_ipop.sh $rc_dir/S91update_ipop \
  $init_dir/ipop.sh $rc_dir/S92ipop \
  $init_dir/gridcndor.sh $rc_dir/S93gridcndor \
  $init_dir/xison.sh $rc_dir/S99xison

