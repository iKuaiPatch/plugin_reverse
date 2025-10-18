#!/bin/bash
BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="$(jq -r '.name' $INSTALL_DIR/html/metadata.json)"
chmod +x $INSTALL_DIR/script/*
. /etc/mnt/plugins/configs/config.sh

. /etc/release

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
	rm -f /tmp/iktmp/plugins/clash_installed

	# Common 安装项
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_$PLUGIN_NAME
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh
	
	# Clash专用安装项目
	debug "开始安装插件$PLUGIN_NAME， 安装类型为：$type"
	if [ "$type" = "upgrade" -o "$type" = "reinstall" ]; then
		debug "更新安装，先停止插件并清除临时目录"
		/usr/ikuai/function/plugin_$PLUGIN_NAME stop
		rm -rf /tmp/ShellCrash/
	fi
	
	if [ "$type" = "reinstall" ]; then
		debug "更新模式为重新安装，清除配置文件"
		rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	fi

	if [ "$type" = "new" -o "$type" = "reinstall" ]; then
		debug "首次安装或重新安装，配置文件持久化处理"
		sed -i "s#^BINDIR=.*#BINDIR=$INSTALL_DIR/bin#g" $INSTALL_DIR/bin/configs/command.env
		mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
		cp -rf $INSTALL_DIR/bin/configs $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	fi

	debug "重建配置文件软连接"
	rm -rf $INSTALL_DIR/bin/configs 
	mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/yamls
	mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/jsons
	mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/ui
	ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/configs $INSTALL_DIR/bin/configs
	ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/yamls $INSTALL_DIR/bin/yamls
	ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/jsons $INSTALL_DIR/bin/jsons
	ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/ui $INSTALL_DIR/bin/ui

	# 添加ttyd
	if [ -f $INSTALL_DIR/bin/ttyd ]; then
		chmod +x $INSTALL_DIR/bin/ttyd
		ln -sf $INSTALL_DIR/bin/ttyd /usr/bin/ttyd
	fi

	# AP模式下启用IPV6, 这样才可以用IPV6的代理节点
	if [ "$CURRENT_APMODE" ]; then
		sysctl -w -q net.ipv6.conf.br-lan.disable_ipv6=0
		sysctl -w -q net.ipv6.conf.br-lan.autoconf=1
		sysctl -w -q net.ipv6.conf.br-lan.accept_ra=2
	fi

	chrootmgt mount_plugin "$PLUGIN_NAME"
	chrootmgt set_profile "export OLDPWD=$EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin" "$PLUGIN_NAME"
	chrootmgt set_profile "export CRASHDIR=$EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin" "$PLUGIN_NAME"
	chrootmgt set_profile "alias crash='sh $INSTALL_DIR/bin/menu.sh'" "$PLUGIN_NAME"
	chrootmgt set_profile "alias clash='sh $INSTALL_DIR/bin/menu.sh'" "$PLUGIN_NAME"

	# 自动启动插件
	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ]; then

		# 添加定时更新任务
		autoupdate=$(cat /etc/crontabs/cron.d/clash|grep "更新订阅"|wc -l)
		if [ $autoupdate -eq 0 ];then
			taskCmd="0 8 * * * $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/task/task.sh 104 在每日的8点0分更新订阅并重启服务"
			echo "$taskCmd" >>/etc/crontabs/cron.d/clash
			echo "$taskCmd" >>/etc/crontabs/root
		fi

		/usr/ikuai/function/plugin_$PLUGIN_NAME start
	fi
	debug "插件 $PLUGIN_NAME 安装完成"
	touch /tmp/iktmp/plugins/clash_installed
}

__uninstall()
{
	# Clash专用卸载项
	/usr/ikuai/function/plugin_$PLUGIN_NAME stop
	rm -rf /tmp/ShellCrash/
	rm -f /tmp/iktmp/plugins/clash_installed

	chrootmgt umount_plugin "$PLUGIN_NAME"
	chrootmgt clean_profile "$PLUGIN_NAME"

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
