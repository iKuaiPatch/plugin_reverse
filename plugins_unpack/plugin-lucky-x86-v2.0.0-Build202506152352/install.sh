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
	rm -f /tmp/iktmp/plugins/lucky_installed

	# Common 安装项
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_$PLUGIN_NAME
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

	# Lucky专用安装项目
	debug "开始安装插件$PLUGIN_NAME， 安装类型为：$type"
	if [ "$type" = "upgrade" -o "$type" = "reinstall" ]; then
		debug "更新安装，先停止插件并清除临时目录"
		/usr/ikuai/function/plugin_$PLUGIN_NAME stop
	fi
	
	if [ "$type" = "reinstall" ]; then
		debug "更新模式为重新安装，清除配置文件"
		rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	fi

	if [ "$type" = "new" -o "$type" = "reinstall" ]; then
		debug "首次安装或重新安装，配置文件持久化处理"
		mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	fi

	# 自动启动插件
	[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && /usr/ikuai/function/plugin_$PLUGIN_NAME start

	touch /tmp/iktmp/plugins/lucky_installed
}

__uninstall()
{
	/usr/ikuai/function/plugin_$PLUGIN_NAME stop

	rm -rf $INSTALL_DIR
	rm -f /tmp/iktmp/plugins/lucky_installed
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	rm -f $EXT_PLUGIN_IPK_DIR/$PLUGIN_NAME.ipk
	rm -f $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME.log
	rm -f /usr/ikuai/function/plugin_$PLUGIN_NAME

	# rm -f /usr/bin/vnt
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
