#!/bin/bash

### BEGIN INIT INFO
# Provides:          cow
# Required-Start:
# Required-Stop:
# Default-Start:     S
# Default-Stop:       
# X-Start-Before:    mountkernfs
# Short-Description: COW
# Description:       Begins Copy-on-Write / Modules for Grid Appliance
### END INIT INFO

FUSE_OPT="-oallow_other,use_ino,suid,dev,nonempty"
UNION_OPT="-ocow,chroot=/tmp,max_files=32768"

if test -e /dev/sda1; then
  DRIVE_PREFIX="s"
  DRIVE=(a b c d)
else
  DRIVE_PREFIX="h"
  DRIVE=(a b d)
fi

if [[ $1 == "start" ]]; then
  mount -n -t proc none /proc &> /dev/null
  mount -t tmpfs none /tmp
  mkdir /tmp/home /tmp/opt /tmp/root /tmp/union

  union_mount="/opt=rw"
  mount -text3 /dev/"$DRIVE_PREFIX"d"${DRIVE[1]}"1 /tmp/opt

# If we have a third drive, we'll mount it as home
  if test -e $DRIVE_PREFIX"d"${DRIVE[1]}1; then
    union_mount="/home=rw:/opt=ro"
    mount -text3 /dev/"$DRIVE_PREFIX"d"${DRIVE[2]}"1 /tmp/home
 fi

  mount --bind / /tmp/root
  unionfs-fuse $FUSE_OPT $UNION_OPT $union_mount:/root=ro /tmp/union
  cd /tmp/union
  pivot_root . .oldroot

  if test -e $DRIVE_PREFIX"d"${DRIVE[3]}1; then
    mount /dev/$DRIVE_PREFIX"d"${DRIVE[3]}1 /mnt/local
  elif test -e $DRIVE_PREFIX"d"${DRIVE[3]}1; then
    mkdir -p /.oldroot/tmp/home/mnt/local &> /dev/null
    mount --bind /.oldroot/tmp/home/mnt/local /mnt/local &> /dev/null
  fi

  chown -R :users /mnt/local &> /dev/null
  chmod -R 775 /mnt/local &> /dev/null

  mount -n -t proc none /proc &> /dev/null
  cat /proc/mounts > /etc/mtab

# A hack to deal with UnionFS-Fuse not reidrecting inotify
  if test -e /sbin/initctl; then
    /sbin/initctl reload-configuration
    /sbin/initctl emit startup &
  fi

  echo "Mounting CoW complete"
fi
