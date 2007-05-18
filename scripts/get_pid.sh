#!/bin/bash
# retrieves $1's pid
value=`ps uax | grep $1 | grep -v grep | grep -v get_pid.sh | awk -F" " {'print $2'}` 2> /dev/null
value=`echo $value | awk -F" " {'print $1'}`
echo -n $value


