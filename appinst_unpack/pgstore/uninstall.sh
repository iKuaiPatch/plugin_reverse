#!/bin/bash 
BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="$(jq -r '.name' $INSTALL_DIR/html/metadata.json)"
chmod +x $INSTALL_DIR/script/*

. /etc/release
# [ "$CURRENT_APMODE" ] && exit 0

install()
{
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_pgstore

	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh
	if ! grep -q "PLUGIN_NAME=" $INSTALL_DIR/script/service.sh; then 
		sed -i "2 i\PLUGIN_NAME=\"${PLUGIN_NAME}\"" $INSTALL_DIR/script/service.sh
	fi
}

__uninstall()
{
	rm -rf $INSTALL_DIR
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	rm -f /usr/ikuai/function/plugin_pgstore
	rm -f $EXT_PLUGIN_IPK_DIR/$PLUGIN_NAME.ipk
	rm -f $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME.log
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
