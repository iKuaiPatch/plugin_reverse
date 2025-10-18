#!/bin/bash
BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="$(jq -r '.name' $INSTALL_DIR/html/metadata.json)"
chmod +x $INSTALL_DIR/script/*
. /etc/mnt/plugins/configs/config.sh

debug() {
	debuglog=$( [ -s /tmp/debug_on ] && cat /tmp/debug_on || echo -n /tmp/debug.log )
    if [ "$1" = "clear" ]; then
        rm -f $debuglog && return
    fi

    if [ -f /tmp/debug_on ]; then
        TIME_STAMP=$(date +"%Y%m%d %H:%M:%S")
        echo "[$TIME_STAMP]: PL> $1" >>$debuglog
    fi
}

install()
{
	# 安装类型如下：
	# 1、new:新安装; 
	# 2、upgrade:保留配置更新; 
	# 3、reinstall:不保留配置更新; 
	# 4、boot:开机启动
	type=$1 

	if [ -f /tmp/iktmp/plugins/vremote_installed ]; then
		rm -f /tmp/iktmp/plugins/vremote_installed
		/usr/ikuai/function/plugin_$PLUGIN_NAME stop
	fi

	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_$PLUGIN_NAME
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

	mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME

	if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/lastShareSyncTime ]; then
		# 默认开启代理
		touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/enableProxy
	fi

	# 如果不存在配置文件且存在OEM注入的预定义配置文件，则复制到配置目录
	if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config ]; then
		if [ -f $INSTALL_DIR/predefined-config ]; then
			cp -f $INSTALL_DIR/predefined-config $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config
			touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart
		fi
	fi

	chmod +x $INSTALL_DIR/script/vremote.sh
	ln -s $INSTALL_DIR/script/vremote.sh /usr/bin/vremote

	# 自动启动插件
	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ]; then
		(
			while true; do
				/usr/ikuai/function/plugin_$PLUGIN_NAME start
				[ $? -eq 0 ] && break
				debug "VRemote自动启动失败，30秒后重试！"
				sleep 30
			done
			debug "VRemote自动启动成功！"
			touch /tmp/iktmp/plugins/vremote_installed
		) >/dev/null 2>&1 &
	else
	 	touch /tmp/iktmp/plugins/vremote_installed
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

	rm -f /tmp/iktmp/plugins/${PLUGIN_NAME}_installed
	rm -f /usr/bin/vremote
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
