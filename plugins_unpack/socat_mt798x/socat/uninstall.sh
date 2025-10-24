#!/bin/bash 
PLUGIN_NAME="socat"

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

	killall socat
	rm /etc/log/socat -r -f
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm /etc/log/IPK/$PLUGIN_NAME -r -f
	rm $plugin_dir/../../../$PLUGIN_NAME -r -f
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
