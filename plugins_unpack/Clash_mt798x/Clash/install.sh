#!/bin/bash
PLUGIN_NAME="Clash"
local BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x $INSTALL_DIR/script/*
install()
{

		EXT_PLUGIN_CONFIG_DIR=/etc/mnt/plugins/configs
	if [ ! -d $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME ];then
		mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	fi
	
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/$PLUGIN_NAME.sh         /usr/ikuai/function/plugin_$PLUGIN_NAME

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

	# 自动启动插件
	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ]; then
		/usr/ikuai/function/plugin_$PLUGIN_NAME start
	fi

}

__uninstall()
{
	rm /etc/log/IPK/$PLUGIN_NAME -r -f
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
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
