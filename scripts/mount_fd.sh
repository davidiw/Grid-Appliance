#!/bin/bash
mkdir /mnt/fd
device="/dev/fd0"
modprobe floppy
mount $device /mnt/fd
