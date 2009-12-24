#!/bin/bash
source /etc/grid_appliance.config

user=$1
#Password == password
password=$(echo password | openssl passwd -1 -stdin)
useradd $user --password $password --shell /bin/bash --groups users,admin,plugdev,lpadmin,sambashare --home-dir /home/$user -U
rm -rf /home/$user
cp -axf $DIR/user /home/$user
sed -i "s/USERNAME/$user/g" /home/$user/.icewm/preferences
chown -R $user:$user /home/$user
