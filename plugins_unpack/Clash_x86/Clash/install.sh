#!/bin/bash
PLUGIN_NAME="Clash"
local BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x $INSTALL_DIR/script/*
install()
{
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/$PLUGIN_NAME.sh         /usr/ikuai/function/plugin_$PLUGIN_NAME
	ShellCrash=`cat "/tcp/setup/setup.other"|grep "ShellCrash"|wc -l`
	export OLDPWD='/tmp/log/ShellCrash'
	export CRASHDIR='/tmp/log/ShellCrash'
	alias crash='sh /tmp/log/ShellCrash/menu.sh'
	alias clash='sh /tmp/log/ShellCrash/menu.sh'
	rm $INSTALL_DIR/data -rf
	mv $INSTALL_DIR/datas $INSTALL_DIR/data
	
	if [ ! -d /etc/mnt/ShellCrash ];then
		rm /tmp/log/ShellCrash -rf
	fi
	
	if [ ! -d /tmp/log/ShellCrash ];then
		
		tar -xvf $INSTALL_DIR/data/ShellCrash.tar  -C /tmp/log/
		rm  $INSTALL_DIR/data/ShellCrash.tar
		else
		rm  $INSTALL_DIR/data/ShellCrash.tar
	fi
	
	if [ ! -d /etc/mnt/ShellCrash ];then
		mkdir /etc/mnt/ShellCrash -p
		cp /tmp/log/ShellCrash/configs /etc/mnt/ShellCrash/ -r
		cp /tmp/log/ShellCrash/task /etc/mnt/ShellCrash/ -r
	fi

    if [ ! -d /etc/mnt/ShellCrash/yamls ];then
	 mkdir -p /etc/mnt/ShellCrash/yamls
	fi
	
    if [ ! -d /etc/mnt/ShellCrash/jsons ];then
	 mkdir -p /etc/mnt/ShellCrash/jsons
	fi
	
	if [ ! -d /etc/mnt/ShellCrash/ruleset ];then
	 mkdir -p /etc/mnt/ShellCrash/ruleset
	fi
	
	rm /tmp/log/ShellCrash/configs -rf
	rm /tmp/log/ShellCrash/task -rf
	rm /tmp/log/ShellCrash/yamls -rf
	rm /tmp/log/ShellCrash/jsons -rf
	
	ln -sf /etc/mnt/ShellCrash/configs /tmp/log/ShellCrash/
	ln -sf /etc/mnt/ShellCrash/task /tmp/log/ShellCrash/
	ln -sf /etc/mnt/ShellCrash/yamls /tmp/log/ShellCrash/
	ln -sf /etc/mnt/ShellCrash/jsons /tmp/log/ShellCrash/
	ln -sf /etc/mnt/ShellCrash/ruleset /tmp/log/ShellCrash/
	chmod +x /tmp/log/ShellCrash/task/*
	chmod +x /tmp/log/ShellCrash/*

}

__uninstall()
{
	rm /tmp/log/IPK/$PLUGIN_NAME -r -f
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm /etc/log/ikipk/$PLUGIN_NAME
	rm /tmp/ikipk/$PLUGIN_NAME
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
