#!/bin/bash 
PLUGIN_NAME="socks5"
local BASH_SOURCE=$0
plugin_link=`readlink $BASH_SOURCE`
plugin_dir=`dirname $plugin_link`
plugin_dir=$plugin_dir
install()
{
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME

	ln -sf $INSTALL_DIR/script/$PLUGIN_NAME.sh         /usr/ikuai/function/plugin_$PLUGIN_NAME

}

__uninstall()
{
	killall $PLUGIN_NAME
	killall $PLUGIN_NAME
	sh /etc/log/ShellCrash/menu.sh -s stop >/dev/null 2>&1
	killall CrashCore
	rm /tmp/ShellCrash -r
	rm /etc/log/ShellCrash -rf
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm $plugin_dir/../../../$PLUGIN_NAME -r
	rm /etc/log/ikipk/$PLUGIN_NAME -r -f
	rm /etc/log/app_dir/$PLUGIN_NAME -rf
	rm /etc/log/IPK/$PLUGIN_NAME -rf

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
