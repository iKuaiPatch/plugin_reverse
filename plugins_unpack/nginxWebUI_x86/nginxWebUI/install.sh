#!/bin/bash
PLUGIN_NAME="nginxWebUI"
local BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x $INSTALL_DIR/script/*
install()
{
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME

	ln -sf $INSTALL_DIR/script/nginxWebUI.sh         /usr/ikuai/function/plugin_nginxWebUI

}

__uninstall()
{
	killall $PLUGIN_NAME
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	MOUNT_POINT="/etc/log/chroot_nginxWebUI"
	mount | grep "$MOUNT_POINT" | awk '{print $3}' | while read -r mount_path; do
	umount "$mount_path"
	done
	rm /etc/log/chroot/$PLUGIN_NAME/data/$PLUGIN_NAME
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
