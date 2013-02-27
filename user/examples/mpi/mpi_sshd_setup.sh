#!/bin/bash
path=$_CONDOR_SCRATCH_DIR/ssh

mkdir $path
cp $_CONDOR_SCRATCH_DIR/authorized_keys $path/authorized_keys
echo "AuthorizedKeysFile "$path"/authorized_keys" > $path/sshd_config
echo "HostKey "$path"/ssh_host_rsa_key" >> $path/sshd_config 
echo "HostKey "$path"/ssh_host_dsa_key" >> $path/sshd_config 
echo "Port "$(expr 55555 + $_CONDOR_SLOT) >> $path/sshd_config 
echo "ListenAddress 0.0.0.0" >> $path/sshd_config 
echo "PasswordAuthentication no" >> $path/sshd_config 
echo "StrictModes no" >> $path/sshd_config
echo "Protocol 2" >> $path/sshd_config

ssh-keygen -t rsa -f $path/ssh_host_rsa_key -q -N ""
ssh-keygen -t dsa -f $path/ssh_host_dsa_key -q -N ""

sshd=$(which sshd)
$sshd -f $path/sshd_config

