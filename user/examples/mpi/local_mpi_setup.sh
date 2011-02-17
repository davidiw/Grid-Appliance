#!/bin/bash

mpi_ver=1.3.1
mpi_prefix=mpich2

hostname=`hostname | awk -F "." '{print $1}'`
path=/mnt/ganfs/$hostname
OPT="--prefix=$path/$mpi_prefix --disable-f77 --disable-cxx --disable-fc --with-pm=mpd"

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

if [[ ($1 != "-f") && ($# -eq 1) ]]; then echo "Unknown option"; exit 1; fi
if [ $# -gt 1 ]; then echo "Invalid number of arguments"; exit 1; fi

if [[ ( $1 != "-f" ) && ( -e $path/$mpi_prefix/bin/mpd.py ) ]]; then
    echo "MPI has already been installed in $path/$mpi_prefix."
    exit 1
fi

if [ ! -d $path ]; then echo "Error: path $path doesn't exist"; exit 1; fi
if [ -d $path/$mpi_prefix ]; then rm -rf $path/$mpi_prefix; fi

echo "========================================"
echo "Installing MPI in "$path
echo "========================================"

echo -ne "Downloading mpich2 ............"
wget http://www.mcs.anl.gov/research/projects/mpich2/downloads/tarballs/1.3.1/mpich2-1.3.1.tar.gz &> /dev/null &
spinner $!
if [ "$?" -ne 0 ]; then echo "failed"; exit 1; fi 
echo "done"

tar xfz $mpi_prefix"-"$mpi_ver".tar.gz" &> /dev/null
if [ "$?" -ne 0 ]; then echo "Error extracting mpich2 package"; exit 1; fi

mkdir $path/$mpi_prefix &> /dev/null
cd $mpi_prefix-$mpi_ver

echo -ne "Configure mpich2 .............."
export CC="gcc -m32"
./configure $OPT &> /dev/null &
spinner $!
if [ "$?" -ne 0 ]; then echo "failed"; exit 1; fi 
echo "done"

echo -ne "Building mpich2 ..............."
make &> /dev/null &
spinner $!
if [ "$?" -ne 0 ]; then echo "failed"; exit 1; fi 
echo "done"

echo -ne "Installing mpich2 ............."
make install &> /dev/null &
spinner $!
if [ "$?" -ne 0 ]; then echo "failed"; exit 1; fi 
echo "done"

cd ..

rm -f $mpi_prefix-$mpi_ver.tar.gz
rm -rf $mpi_prefix-$mpi_ver
