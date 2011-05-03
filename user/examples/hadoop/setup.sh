#!/bin/bash

function install_jdk() {

    echo "========================================"
    echo "Installing JDK in "$path
    echo "========================================"

    # download jdk if not already exist
    if [[ ! -e $jdk_file ]]; then
        echo "Downloading JDK ......... "
        wget http://download.oracle.com/otn-pub/java/jdk/6u25-b06/$jdk_file
    fi
    [[ -e $jdk_file ]] || exit 1

    mv $jdk_file $path
    jdk_fname=`basename $jdk_file`
    echo "Installing JDK ........... "
    cd $path
    chmod a+x $jdk_fname
    echo "Y" | ./$jdk_fname
    [[ "$?" -eq 0 ]] || exit 1

    rm -f $jdk_file            # remove installation file
    mv -f jdk?.?.* $jdk_dir        # rename jdk dir
    cd $curr_path
}

function install_hadoop() {

    echo "========================================"
    echo "Installing Hadoop in "$path
    echo "========================================"

    # download hadoop if not already exist
    if [[ ! -e $hadoop_file ]]; then
        echo "Downloading Hadoop ......... "
        wget http://mirror.nyi.net/apache//hadoop/core/hadoop-$hadoop_ver/$hadoop_file
    fi
    [[ -e $hadoop_file ]] || exit 1

    mv $hadoop_file $path
    cd $path
    echo "Installing Hadoop ........ "
    tar xvfz $hadoop_file 
    [[ "$?" -eq 0 ]] || exit 1

    rm -f $hadoop_file
    mv -f hadoop-$hadoop_ver $hadoop_dir

    cd $curr_path
}


for opt in "$@"; do
    case $opt in
        "-f")
            reinstall=true
            ;;
        *)
            echo "Invalid option $opt"
            echo "Usage: [-f]"
            exit 1
    esac
done

jdk_dir=jdk
hadoop_dir=hadoop

hostname=$(hostname -s)
path=/mnt/ganfs/$hostname
curr_path=`pwd`

jdk_file=jdk-6u25-linux-i586.bin
hadoop_ver=0.21.0
hadoop_file=hadoop-$hadoop_ver.tar.gz

# Check path
if [[ ! -d $path ]]; then
    echo "Error: path $path doesn't exist."
    echo "Do you have grid-appliance-autofs and grid-appliance-nfs installed?"
    exit 1
fi

# Install
if [[ ! "$reinstall" && -e $path/$jdk_dir/bin/java ]]; then
    echo "JDK has already been installed in $path/$jdk_dir" 
else
    rm -rf $path/$jdk_dir >& /dev/null
    install_jdk
fi

if [[ ! "$reinstall" && -e $path/$hadoop_dir/bin/hadoop ]]; then
    echo "Hadoop has already been installed in $path/$hadoop_dir" 
else
    rm -rf $path/$hadoop_dir >& /dev/null
    install_hadoop
fi
