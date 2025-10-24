#!/bin/bash 

PLUGIN_NAME="Clash"

plugin_link=`readlink $BASH_SOURCE`
plugin_dir=`dirname $plugin_link`
plugin_dir=$plugin_dir

DOCKER_ENGINE_PATH=$INSTALL_DIR
install()
{
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $DOCKER_ENGINE_PATH/html /usr/ikuai/www/plugins/$PLUGIN_NAME

	ln -sf $DOCKER_ENGINE_PATH/script/$PLUGIN_NAME.sh         /usr/ikuai/function/plugin_$PLUGIN_NAME

}

__uninstall()
{

	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	sh /etc/log/ShellCrash/menu.sh -s stop
	killall CrashCore
	rm /tmp/ShellCrash -r
	rm /etc/log/ShellCrash -rf
	rm $plugin_dir/../../../$PLUGIN_NAME -rf
	rm /etc/log/IPK/$PLUGIN_NAME -rf
	rm /etc/log/IPK/$PLUGIN_NAME -rf
	rm /etc/log/ikipk/$PLUGIN_NAME -rf
	
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
