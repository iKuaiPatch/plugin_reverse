#!/bin/bash
PLUGIN_NAME="appinst"
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"


install()
{

chmod +x $INSTALL_DIR/appinst
$INSTALL_DIR/appinst >/dev/null &

}

__uninstall()
{

	exit
}

procname=$(basename $BASH_SOURCE)
if [ "$procname" = "install.sh" ];then
        install
elif [ "$procname" = "uninstall.sh" ];then
        uninstall
fi
