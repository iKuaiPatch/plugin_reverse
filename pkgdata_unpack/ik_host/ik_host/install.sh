#!/bin/bash

export MD5_PATH="/tmp/.ik_host_md5"

mkdir -p $MD5_PATH

filelist=`ls $INSTALL_DIR`
for file in $filelist
do
	if [ -f $INSTALL_DIR/$file/install.sh ];then
		bash $INSTALL_DIR/$file/install.sh 
	fi
done
