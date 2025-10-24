#!/bin/bash 
PLUGIN_NAME="Jellyfin"
local BASH_SOURCE=$0
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

	killall $PLUGIN_NAME
	
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm /etc/log/ikipk/$PLUGIN_NAME -r -f
	rm $plugin_dir/../../../$PLUGIN_NAME -r -f
	rm $plugin_dir/../data/* -rf
MOUNT_POINT="/etc/log/chroot_jellyfin"
mount | grep "$MOUNT_POINT" | awk '{print $3}' | while read -r mount_path; do
umount "$mount_path"
done
	rm /etc/log/chroot_jellyfin -rf
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

