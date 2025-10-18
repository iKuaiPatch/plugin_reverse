#!/bin/bash
BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="$(jq -r '.name' $INSTALL_DIR/html/metadata.json)"
chmod +x $INSTALL_DIR/script/*
. /etc/mnt/plugins/configs/config.sh
if [[ "$EXT_PLUGIN_RUN_INMEM" = "yes" && -f "$EXT_PLUGIN_IPK_DIR" ]]; then
     # 兼容京东云，它的闪存空间太小了，放不下
    EXT_PLUGIN_CONFIG_DIR=$EXT_PLUGIN_IPK_DIR
fi

install()
{
	# 安装类型如下：
	# 1、new:新安装; 
	# 2、upgrade:保留配置更新; 
	# 3、reinstall:不保留配置更新; 
	# 4、boot:开机启动
	type=$1 
	rm -f /tmp/iktmp/plugins/alist_installed

	# Common 安装项
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_$PLUGIN_NAME
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

	# alist专用安装项目
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

	# 为log和temp文件建立软连接，主要针对硬路由优化，log和temp不适合存放在持久化的闪存目录
	mkdir -p $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME/log $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME/temp
	ln -sf $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME/log $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/log
	ln -sf $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME/temp $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/temp

	tar -xzf $INSTALL_DIR/bin/alist.tar.gz -C $INSTALL_DIR/bin
	rm $INSTALL_DIR/bin/alist.tar.gz
	chmod +x $INSTALL_DIR/bin/alist

	# 自动启动插件
	[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && /usr/ikuai/function/plugin_$PLUGIN_NAME start

	touch /tmp/iktmp/plugins/alist_installed
}

__uninstall()
{
	/usr/ikuai/function/plugin_$PLUGIN_NAME stop

	rm -rf $INSTALL_DIR
	rm -f /tmp/iktmp/plugins/alist_installed
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	rm -f $EXT_PLUGIN_IPK_DIR/$PLUGIN_NAME.ipk
	rm -f $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME.log
	rm -f /usr/ikuai/function/plugin_$PLUGIN_NAME

	rm -rf /tmp/$PLUGIN_NAME
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
