#!/bin/bash
install_path="/etc/cre.d"
install_host="cre_host"
cre_version=`cre -v`
cre_sig=108
cre_pid=$(cat /var/run/collect_report_engine.pid 2>/dev/null)
md5_version=`md5sum $INSTALL_DIR/cre_host/cre_host | awk '{print($1)}'`
md5_file="cre_host_md5"

if [ -f $install_path/$install_host ]; then
	rm $install_path/$install_host
fi

mkdir $install_path -p

ln -s $INSTALL_DIR/cre_host/cre_host $install_path/$install_host

if [ -f $MD5_PATH/$md5_file ] && [ `cat $MD5_PATH/$md5_file` == "$md5_version" ];then
	exit
else
	echo $md5_version > $MD5_PATH/$md5_file
fi

if [ "X$cre_version" != "X" ] && [ $cre_version -ge $cre_sig ] && [ -n "$cre_pid" ]; then
	kill -s SIGUSR1 "$cre_pid" 2>/dev/null
fi
