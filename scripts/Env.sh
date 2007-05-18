#!/bin/bash
Setup=`uname -r | awk -F"xen" '{print $2}'`
if [[ $Setup = "0" || $Setup = "U" ]]; then
  Setup="xen"$Setup
else
  Setup="linux"
fi
echo $Setup