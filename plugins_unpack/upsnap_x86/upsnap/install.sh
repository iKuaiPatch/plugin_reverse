#!/bin/bash
PLUGIN_NAME="upsnap"
BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x $INSTALL_DIR/script/*
. /etc/mnt/plugins/configs/config.sh
install()
{
        rm -f /etc/log/app_dir/${PLUGIN_NAME}_installed
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/upsnap.sh /usr/ikuai/function/plugin_$PLUGIN_NAME
        mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
        chmod  +x $INSTALL_DIR/data/upsnap
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
