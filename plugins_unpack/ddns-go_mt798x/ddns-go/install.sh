#!/bin/bash
PLUGIN_NAME="ddns-go"
local BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x $INSTALL_DIR/script/*
install()
{
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME

	ln -sf $INSTALL_DIR/script/ddns-go.sh         /usr/ikuai/function/plugin_ddns-go

}

__uninstall()
{

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
