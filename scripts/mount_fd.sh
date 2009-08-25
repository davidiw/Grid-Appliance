#!/bin/bash

mkdir /mnt/fd
modprobe floppy
mount /dev/fd0 /mnt/fd
