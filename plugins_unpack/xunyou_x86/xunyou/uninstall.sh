#!/bin/bash 
PLUGIN_NAME="xunyou"
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")

install()
{
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/$PLUGIN_NAME.sh         /usr/ikuai/function/plugin_$PLUGIN_NAME
}

__uninstall()
{
	killall $PLUGIN_NAME
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	for pid in $(ps | grep "xunyou" | grep -v "grep" | awk '{print $1}'); do
	kill -9 $pid
	rm /tmp/xunyou -rf
	rm /tmp/ikipk/xunyou -rf
	rm /tmp/.xunyou_install -rf
	done
	
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
