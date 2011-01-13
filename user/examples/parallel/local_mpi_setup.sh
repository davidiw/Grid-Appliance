#!/bin/bash

mpi_ver=1.3.1
mpi_prefix=mpich2

hostname=`hostname | awk -F "." '{print $1}'`
path=/mnt/ganfs/$hostname

function spinner() {
    p=$1
    int=0.2
    echo -en "  "
    while [ -d /proc/$p ]; do
        echo -en '\b\b/ '; sleep $int
        echo -en '\b\b- '; sleep $int
        echo -en '\b\b\\ '; sleep $int
        echo -en '\b\b| '; sleep $int
    done
    echo -en '\b\b'
    return 0
}

if [ -e $path/$mpi_prefix/bin/mpd.py ]; then
    echo "MPI has already been installed."
    return 1
fi

echo "========================================"
echo "Installing MPI in "$path
echo "========================================"

tar xfz $mpi_prefix"-"$mpi_ver".tar.gz"
if [[ $? != 0 ]]; then
    return 1
fi

mkdir $path/$mpi_prefix &> /dev/null
cd $mpi_prefix-$mpi_ver

echo -ne "Configure MPI ..........."
./configure --prefix=$path/$mpi_prefix --disable-f77 --disable-fc --with-pm=mpd &> /dev/null &
spinner $!
echo "done"

echo -ne "Building MPI ............"
make &> /dev/null &
spinner $!
echo "done"


echo -ne "Installing MPI .........."
make install &> /dev/null &
spinner $!
echo "done"


cd ..
rm -rf $mpi_prefix-$mpi_ver
