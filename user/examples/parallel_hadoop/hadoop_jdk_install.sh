#!/bin/bash

jdk_dir=jdk
hadoop_dir=hadoop

hostname=`hostname | awk -F "." '{print $1}'`
path=/mnt/ganfs/$hostname
curr_path=`pwd`

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

function install_jdk() {

    echo "========================================"
    echo "Installing JDK in "$path
    echo "========================================"

    cp $jdk_file $path
    jdk_fname=`basename $jdk_file`
    echo -ne "Installing JDK ........... "
    cd $path
    echo "Y" | ./$jdk_fname &> /dev/null &
    spinner $!
    echo "done"

    rm -f $jdk_file            # remove installation file
    mv -f jdk?.?.* $jdk_dir        # rename jdk dir
    cd $curr_path
}

function install_hadoop() {

    echo "========================================"
    echo "Installing Hadoop in "$path
    echo "========================================"

    cp $hadoop_file $path
    cd $path
    echo -ne "Installing Hadoop ........ "
    tar xfz $hadoop_file &> /dev/null &
    spinner $!
    echo "done"

    rm -f $hadoop_file
    mv -f hadoop-?.* $hadoop_dir

    # add required JAVA_HOME to hadoop conf
    echo "export JAVA_HOME=$path/$jdk_dir" >> $hadoop_dir/conf/hadoop-env.sh
    cd $curr_path
}

function print_usage() {

    echo "Usage: $0 {-j <java installation file>} {-h <hadoop installation file>}"
}


# Check arguements
if [ $# != 4 ]; then
    print_usage
    exit 1
fi

# Parsing options
if [ $1 = "-j" -a $3 = "-h" ]; then
   jdk_file=$2
   hadoop_file=$4
elif [ $1 = "-h" -a $3 = "-j" ]; then
   jdk_file=$4
   hadoop_file=$2
else
    print_usage
    exit 1
fi

# Check file existance
if [ ! -f $jdk_file ]; then
    echo "Error: cannot find $jdk_file"
    print_usage
    exit 1
fi

if [ ! -f $hadoop_file ]; then
    echo "Error: cannot find $hadoop_file"
    print_usage
    exit 1
fi

# Install
if [ -f $path/$jdk_dir/bin/java ]; then
    echo "JDK is already existed in $path/$jdk_dir .... skipping" 
else
    install_jdk
fi

if [ -f $path/$hadoop_dir/bin/hadoop ]; then
    echo "Hadoop is already existed in $path/$hadoop_dir .... skipping" 
else
    install_hadoop
fi
