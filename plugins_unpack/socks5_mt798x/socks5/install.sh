#!/bin/bash
PLUGIN_NAME="socks5"
local BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x $INSTALL_DIR/script/*
chmod +x $INSTALL_DIR/data/*
chmod +x $INSTALL_DIR/*



install()
{
	EXT_PLUGIN_CONFIG_DIR=/etc/mnt/plugins/configs
	if [ ! -d $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME ];then
		mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	fi

	sed -i '/\[ ! -f "\$IK_DIR_FUNCAPI\/\$1" \]/!b;n;n;n;c\elif [[ ! "$1" =~ ^plugin_ ]];then' /usr/ikuai/function/func_api.sh
	 if [ -f /etc/log/IPK/Clash ];then
	    rm /etc/log/IPK/Clash -rf
	 fi
	if [ ! -d /etc/log/ShellCrash ];then
		tar -xvf $INSTALL_DIR/data/ShellCrash.tar  -C /etc/log
		chmod +x /etc/log/ShellCrash/task/task.sh
		chmod +x /etc/log/ShellCrash/*
		rm $INSTALL_DIR/data/ShellCrash.tar
	else
		rm $INSTALL_DIR/data/ShellCrash.tar
	fi

	if [ ! -f /etc/log/ShellCrash/CrashCore.tar.gz ];then
		mv $INSTALL_DIR/data/CrashCore.tar.gz /etc/log/ShellCrash/CrashCore.tar.gz
		else
		rm $INSTALL_DIR/data/ShellCrash.tar
	fi


	if [ ! -d /etc/log/ShellCrash/jsons ];then
		mkdir /etc/log/ShellCrash/jsons -p
	fi

	
	cp $INSTALL_DIR/bin/yamls/config.yaml /etc/log/ShellCrash/yamls/config.yaml
	
	if [ -d $INSTALL_DIR/bin/configs ];then
		rm /etc/log/ShellCrash/configs -rf
		mv $INSTALL_DIR/bin/configs /etc/log/ShellCrash/
	fi 
	
		
	if [ -d $INSTALL_DIR/bin/ruleset ];then
		rm /etc/log/ShellCrash/ruleset -rf
		mv $INSTALL_DIR/bin/ruleset /etc/log/ShellCrash/
	fi 
	
	
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME

	ln -sf $INSTALL_DIR/script/$PLUGIN_NAME         /usr/ikuai/function/plugin_$PLUGIN_NAME
	
	
	host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'lan' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
[ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
[ -z "$host" ] && host="127.0.0.1"
sed -i "s/192.168.9.1/${host}/g" /etc/log/ShellCrash//ui/*.html
	
	# 应用自定义规则
	

	/usr/ikuai/function/plugin_$PLUGIN_NAME set_deny_local_net "loadall"
	
	# 自动启动插件
	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ]; then
		/usr/ikuai/function/plugin_$PLUGIN_NAME start
	fi
	

}

__uninstall()
{
	killall $PLUGIN_NAME
	sh /etc/log/ShellCrash/menu.sh -s stop >/dev/null 2>&1
	killall CrashCore
	rm /tmp/ShellCrash -r
	rm /etc/log/ShellCrash -rf
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm $plugin_dir/../../../$PLUGIN_NAME -r
	rm /etc/log/ikipk/$PLUGIN_NAME -r -f
	rm /etc/log/app_dir/$PLUGIN_NAME -r -f
	rm /etc/log/IPK/$PLUGIN_NAME -r -f
}

uninstall()
{
	__uninstall >/dev/null 2>&1
}

procname=$(basename $BASH_SOURCE)
if [ "$procname" = "install.sh" ];then
        install $
elif [ "$procname" = "uninstall.sh" ];then
        uninstall
fi
