#!/bin/bash

filelist=`ls $INSTALL_DIR`
for file in $filelist
do
	if [ -f $INSTALL_DIR/$file/uninstall.sh ];then
		bash $INSTALL_DIR/$file/uninstall.sh
	fi
done
