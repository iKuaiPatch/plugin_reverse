#!/bin/bash 
PLUGIN_NAME="Ttyd"
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
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm $plugin_dir/../../../$PLUGIN_NAME -r
	rm /etc/log/ikipk/$PLUGIN_NAME -r -f
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
