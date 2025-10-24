#!/bin/bash
BASH_SOURCE=$0
PLUGIN_NAME="openp2p"
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x $INSTALL_DIR/script/*
. /etc/mnt/plugins/configs/config.sh
install()
{
	rm -f /etc/log/app_dir/${PLUGIN_NAME}_installed
        mkdir -p /tmp/iktmp/plugins/$PLUGIN_NAME/log
        ln -sf /tmp/iktmp/plugins/$PLUGIN_NAME/log $INSTALL_DIR/bin/log
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_$PLUGIN_NAME
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh
	mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME

	ln -fs $INSTALL_DIR/bin/openp2p /usr/sbin/openp2p
	chmod  +x $INSTALL_DIR/bin/openp2p

	[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && /usr/ikuai/function/plugin_$PLUGIN_NAME start
	touch /etc/log/app_dir/${PLUGIN_NAME}_installed
}

__uninstall()
{
	/usr/ikuai/function/plugin_$PLUGIN_NAME stop
	rm -f /etc/log/app_dir/${PLUGIN_NAME}_installed

	rm -rf $INSTALL_DIR
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	rm -f $EXT_PLUGIN_IPK_DIR/$PLUGIN_NAME.ipk
	rm -f $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME.log
	rm -f /usr/ikuai/function/plugin_$PLUGIN_NAME

	rm /usr/sbin/openp2p
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
