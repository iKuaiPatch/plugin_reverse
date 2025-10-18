#!/bin/bash 
install()
{
	ln -sf $INSTALL_DIR/cloud_ac_black.sh /usr/ikuai/function/cloud_ac_black

	$INSTALL_DIR/cloud_ac_black.sh init
}

uninstall()
{
	rm -f /usr/ikuai/function/cloud_ac_black
}

procname=$(basename $BASH_SOURCE)
if [ "$procname" = "install.sh" ];then
        install
elif [ "$procname" = "uninstall.sh" ];then
        uninstall
fi
