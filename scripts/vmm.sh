#!/bin/bash
echo `cat /proc/1/environ | tr "\0" ":" | awk -F"vmm=" '{print $2}' | awk -F":" '{print $1}'`
