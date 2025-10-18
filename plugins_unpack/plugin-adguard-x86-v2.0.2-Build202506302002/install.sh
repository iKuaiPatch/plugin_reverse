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
	rm -f /tmp/iktmp/plugins/adguard_installed

	# Common 安装项
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_$PLUGIN_NAME
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

	# 专用安装项目
	if [ "$type" = "upgrade" -o "$type" = "reinstall" ]; then
		PID=$(pidof AdGuardHome | awk '{print $NF}')
		[ -n "$PID" ] && kill -9 $PID
		rm -rf /tmp/AdGuardHome
	fi

	if [ "$type" = "reinstall" ]; then
		rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/*
	fi

	if [ "$type" = "new" -o "$type" = "reinstall"  ]; then
		mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/filters
		cp $INSTALL_DIR/config/AdGuardHome.yaml $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
		tar -xzf $INSTALL_DIR/config/filters.tar.gz -C $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/filters
	fi
	
	# 自动启动插件
	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ]; then
		/usr/ikuai/function/plugin_$PLUGIN_NAME start
	fi

	touch /tmp/iktmp/plugins/adguard_installed
}

__uninstall()
{
	# 专用卸载项
	PID=$(pidof AdGuardHome | awk '{print $NF}')
	[ -n "$PID" ] && kill -9 $PID
	rm -f /tmp/iktmp/plugins/adguard_installed
	rm -rf /tmp/AdGuardHome

	# 通用卸载项
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
