#!/bin/bash
#Get the port for $1, whether PID or PORT
value=`netstat -aup | grep $1 | awk -F":" '{print $2}' | awk -F" " '{print $1}'`
value=`echo $value | awk -F" " {'print $1'}`
echo -n $value