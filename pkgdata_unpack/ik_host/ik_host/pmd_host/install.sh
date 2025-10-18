#!/bin/bash
install_path="/etc/pmd.d"
install_host="pmd_host"
pmd_version=`pmd -v`
pmd_sig=114
pmd_pid=$(cat /var/run/pmd.pid 2>/dev/null)
md5_version=`md5sum $INSTALL_DIR/pmd_host/pmd_host | awk '{print($1)}'`
md5_file="pmd_host_md5"

if [ -f $install_path/$install_host ]; then
	rm $install_path/$install_host
fi

mkdir $install_path -p

ln -s $INSTALL_DIR/pmd_host/pmd_host $install_path/$install_host

if [ -f $MD5_PATH/$md5_file ] && [ `cat $MD5_PATH/$md5_file` == "$md5_version" ];then
	exit
else
	echo $md5_version > $MD5_PATH/$md5_file
fi

if [ "X$pmd_version" != "X" ] && [ $pmd_version -ge $pmd_sig ] && [ -n "$pmd_pid" ]; then
	kill -s SIGUSR2 "$pmd_pid" 2>/dev/null
fi
