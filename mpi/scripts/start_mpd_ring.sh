#!/bin/bash

#Checking if user is mpi
iam=`whoami`
if [ $iam != "mpi" ]; then
	echo "This script must be run as 'mpi' user" 1>&2
	exit 1
fi

mpd_x=`ps -ef| grep /usr/bin/mpd | grep mpi| grep -v grep`
current_secret=`cat /home/mpi/.mpd.conf`
if [ "$mpd_x" != "" ]; then 
#mpd ring is already running
	echo "The mpd ring seems to be running. To stop the \
mpd ring run the command 'mpdallexit'"
	exit 1
fi
if [ "$current_secret" = "MPD_SECRETWORD=DefaultSecretWord" ]; then
	echo "*********************************************************************************"
	echo "You are using the default secret word."
	echo "If you are using the default public pool or have more than one mpd ring in the" 
	echo "same GroupVPN, ensure that each mpd ring has its own secret word."
	read -p "Do you want to continue with the default secret word? [y/n] : " response
	while test $response != "y"
	do
		if [ "$response" != "n" ]; then
			read -p "Please enter 'y' or 'n' [y/n] : " response
		else
			echo "To change the secret word, edit the file /home/mpi/.mpd.conf on each node"
			exit 0
		fi
	done	
fi
#Discover MPI hosts
/opt/grid_appliance/scripts/discover_mpi_hosts.sh 2> /dev/null
if test -e /tmp/mpd.hosts; then
	num=`cat /tmp/mpd.hosts| wc -l`
	echo "Starting MPI Deamon on $num MPI appliances."
	mpdboot -n $num -f /tmp/mpd.hosts
	echo -ne "Verifying mpd ring...  "
	num2=`mpdtrace | wc -l`
	if [ "$num" = "$num2" ]; then
		echo "OK"
		exit 0
	else
		mpdallexit
		echo "verification failed"
		echo "Please re-run this script"
		exit 1
	fi
else
	echo "No MPI appliances were discovered! Aborting.."
	exit 1
fi

