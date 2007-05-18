#!/bin/bash
cat /proc/1/environ | tr "\0" ":" | awk -F"release=" '{print $2}' | awk -F":" '{print $1}'
