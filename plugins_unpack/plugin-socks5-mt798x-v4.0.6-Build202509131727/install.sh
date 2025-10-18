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
	debug "开始安装$PLUGIN_NAME ,安装类型为：$type"
	rm -f /tmp/iktmp/plugins/${PLUGIN_NAME}_installed

	CHROOTDIR=$(chrootmgt get_chroot_dir)
	CRASHDIR=$EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin

	debug "检查CrashCore进程是否存在，如果存在先关闭"
	for i in 1 2 3; do
		sleep 1
		crashpid=$(pidof CrashCore)
		if [ -n "$crashpid" ]; then
			chrootmgt run "$CRASHDIR/menu.sh -s stop >/dev/null"
			rm $CHROOTDIR/tmp/ShellCrash -rf
			kill -9 $crashpid
			continue
		else
			break
		fi
		debug "Crash进程存在，无法继续安装"
		return 1
	done

	# Common 安装项
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_$PLUGIN_NAME
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

  # 修改面板默认host
  host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'lan' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	[ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
  [ -z "$host" ] && host="127.0.0.1"
  sed -i "s/192.168.50.1/${host}/g" $INSTALL_DIR/bin/ui/assets/*.js

	# 首次安装或重新安装，则初始化配置文件
	if [ "$type" = "new" -o "$type" = "reinstall" ]; then
		debug "初始化配置文件"
		rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
		mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
		sed -i "s#^BINDIR=.*#BINDIR=$INSTALL_DIR/bin#g" $INSTALL_DIR/bin/configs/command.env
		cp -rf $INSTALL_DIR/bin/configs $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
		cp -rf $INSTALL_DIR/bin/ruleset $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	fi
	# 这几个目录下的安装文件不会被用户修改，所以版本更新时始终将新版文件复制过去，确保更新
	cp -rf $INSTALL_DIR/bin/yamls $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	cp -rf $INSTALL_DIR/bin/jsons $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME

	debug "创建配置文件软连接"
	rm -rf $INSTALL_DIR/bin/configs $INSTALL_DIR/bin/yamls $INSTALL_DIR/bin/jsons $INSTALL_DIR/bin/ruleset
	ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/configs $INSTALL_DIR/bin/configs
	ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/yamls $INSTALL_DIR/bin/yamls
	ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/jsons $INSTALL_DIR/bin/jsons
	ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/ruleset $INSTALL_DIR/bin/ruleset
	
	chrootmgt mount_plugin "$PLUGIN_NAME"
	chrootmgt set_profile "export OLDPWD=$EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin" "$PLUGIN_NAME"
	chrootmgt set_profile "export CRASHDIR=$EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin" "$PLUGIN_NAME"
	chrootmgt set_profile "alias crash='sh $INSTALL_DIR/bin/menu.sh'" "$PLUGIN_NAME"
	chrootmgt set_profile "alias clash='sh $INSTALL_DIR/bin/menu.sh'" "$PLUGIN_NAME"

	# 应用自定义规则
	/usr/ikuai/function/plugin_$PLUGIN_NAME set_deny_local_net "loadall"

	# 自动启动插件
	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ]; then
		/usr/ikuai/function/plugin_$PLUGIN_NAME start
	fi
	debug "插件 $PLUGIN_NAME 安装完成"
	touch /tmp/iktmp/plugins/${PLUGIN_NAME}_installed

}

__uninstall()
{
	# 专用卸载项
	/usr/ikuai/function/plugin_$PLUGIN_NAME stop
	killall CrashCore
	rm -f /tmp/iktmp/plugins/${PLUGIN_NAME}_installed

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
