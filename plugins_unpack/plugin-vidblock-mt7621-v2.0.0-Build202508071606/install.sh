#!/bin/bash
BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="$(jq -r '.name' $INSTALL_DIR/html/metadata.json)"
chmod +x $INSTALL_DIR/script/*
. /etc/mnt/plugins/configs/config.sh

install()
{
	rm -f /tmp/iktmp/plugins/${PLUGIN_NAME}_installed

	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_$PLUGIN_NAME

	mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

	[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && /usr/ikuai/function/plugin_$PLUGIN_NAME start
	touch /tmp/iktmp/plugins/${PLUGIN_NAME}_installed

}

__uninstall()
{
	/usr/ikuai/function/plugin_$PLUGIN_NAME stop
	rm -f /tmp/iktmp/plugins/${PLUGIN_NAME}_installed
	
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
    install ${1-boot}
elif [ "$procname" = "uninstall.sh" ];then
    uninstall
fi
