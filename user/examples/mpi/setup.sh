#!/bin/bash

cc="gcc"
for opt in "$@"; do
  case $opt in
    "-f")
      reinstall=true
      ;;
    "-m32")
      cc="gcc -m32"
      ;;
    *)
      echo "Invalid option $opt"
      echo "Usage: [-m32] [-f]"
      exit 1
  esac
done

mpi_ver=1.3.1
mpi_prefix=mpich2
mpi="$mpi_prefix"-"$mpi_ver"

hostname=$(hostname -s)
path=/mnt/ganfs/$hostname
OPT="--prefix=$path/$mpi_prefix --disable-f77 --disable-cxx --disable-fc --with-pm=mpd"

if [[ ! "$reinstall" && -e $path/$mpi_prefix/bin/mpd.py ]]; then
    echo "MPI has already been installed in $path/$mpi_prefix."
    exit 1
fi

if [[ ! -d $path ]]; then
  echo "Error: path $path doesn't exist."
  echo "Do you have grid-appliance-autofs and grid-appliance-nfs installed?"
  exit 1
fi

if [[ -d $path/$mpi_prefix ]]; then
  rm -rf $path/$mpi_prefix
fi

echo "========================================"
echo "Installing MPI in "$path
echo "========================================"

md5sum=eced41738eca4762b020e5521bb8c53d
if [[ -e mpich2-1.3.1.tar.gz && $md5sum != $(md5sum $mpi.tar.gz) ]]; then 
  rm $mpi.tar.gz
fi

if [[ ! -e mpich2-1.3.1.tar.gz ]]; then
  echo -ne "Downloading mpich2 ............\n"
  wget http://www.mcs.anl.gov/research/projects/mpich2/downloads/tarballs/$mpi_ver/$mpi.tar.gz
fi

[[ ! ( -e mpich2-1.3.1.tar.gz && $md5sum = $(md5sum $mpi.tar.gz) ) ]] || exit 1

[[ -e $mpi ]] && rm -rf $mpi

echo -ne "Extracting mpich2 ............\n"
tar -zxf $mpi.tar.gz 
[[ "$?" -eq 0 ]] || exit 1

mkdir $path/$mpi_prefix
cd $mpi

echo -ne "Configuring mpich2 .............."
export CC=$cc
./configure $OPT
[[ "$?" -eq 0 ]] || exit 1

echo -ne "Building mpich2 ..............."
make 
[[ "$?" -eq 0 ]] || exit 1

echo -ne "Installing mpich2 ............."
make install
[[ "$?" -eq 0 ]] || exit 1

cd ..

rm -rf $mpi
rm -f $mpi.tar.gz
