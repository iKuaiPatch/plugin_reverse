#!/bin/bash 

install()
{
	ln -sf $INSTALL_DIR/ik_stun_client /usr/sbin/ik_stun_client
	return 0
}

uninstall()
{
	rm /usr/sbin/ik_stun_client
	return 0
}

procname=$(basename $BASH_SOURCE)
if [ "$procname" = "install.sh" ];then
        install
elif [ "$procname" = "uninstall.sh" ];then
        uninstall
fi
