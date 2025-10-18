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
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh
	mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME

	ln -fs $INSTALL_DIR/script/autocloud.sh /usr/ikuai/script/autocloud.sh
	chmod  +x /usr/ikuai/script/autocloud.sh

	# 如果不存在配置文件且存在OEM注入的预定义配置文件，则复制到配置目录
	if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud.url ]; then
		if [ -f $INSTALL_DIR/autocloud.url ]; then
			cp -f $INSTALL_DIR/autocloud.url $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud.url
			touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud_enabled
		fi
	fi

	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud_enabled" ]; then
		/usr/ikuai/script/autocloud.sh add_crontab
	fi
	
	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/needturnoffrc" ]; then
		/usr/ikuai/script/autocloud.sh trunoff_cloud
	fi

	touch /tmp/iktmp/plugins/${PLUGIN_NAME}_installed
}

__uninstall()
{
	/usr/ikuai/script/autocloud.sh remove_crontab
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
        install
elif [ "$procname" = "uninstall.sh" ];then
        uninstall
fi
