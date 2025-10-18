#!/bin/bash
BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="$(jq -r '.name' $INSTALL_DIR/html/metadata.json)"
chmod +x $INSTALL_DIR/script/*
. /etc/mnt/plugins/configs/config.sh
install()
{
	# 安装类型如下：
	# 1、new:新安装; 
	# 2、upgrade:保留配置更新; 
	# 3、reinstall:不保留配置更新; 
	# 4、boot:开机启动
	type=$1 

	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_$PLUGIN_NAME

	mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

	if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/msd_lite.conf ]; then
		cp -rf $INSTALL_DIR/bin/msd_lite.conf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	fi

	if [ "$type" = "new" -o "$type" = "reinstall" ]; then
		cp -rf $INSTALL_DIR/bin/msd_lite.conf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	fi
}

__uninstall()
{
	/usr/ikuai/function/plugin_$PLUGIN_NAME stop
	
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
