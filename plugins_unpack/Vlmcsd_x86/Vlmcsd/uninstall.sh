#!/bin/bash 
PLUGIN_NAME="Vlmcsd"

plugin_link=`readlink $BASH_SOURCE`
plugin_dir=`dirname $plugin_link`
plugin_dir=$plugin_dir

DOCKER_ENGINE_PATH=$INSTALL_DIR
install()
{
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $DOCKER_ENGINE_PATH/html /usr/ikuai/www/plugins/$PLUGIN_NAME

	ln -sf $DOCKER_ENGINE_PATH/script/Vlmcsd.sh         /usr/ikuai/function/plugin_Vlmcsd

}

__uninstall()
{
	killall vlmcsd
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
