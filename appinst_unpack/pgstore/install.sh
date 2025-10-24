#!/bin/bash 
PLUGIN_NAME="02.pgstore"
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
#PLUGIN_NAME="$(jq -r '.name' $INSTALL_DIR/html/metadata.json)"
chmod +x $INSTALL_DIR/script/*

. /etc/release
# [ "$CURRENT_APMODE" ] && exit 0

install()
{
	if [ ! -d /etc/mnt/plugins ];then
	 mkdir -p /etc/mnt/plugins
	 	
	fi
	rm /etc/mnt/plugins/configs/config.sh
	rm /etc/mnt/plugins/configs/plugins.json
	cp $INSTALL_DIR/data/configs /etc/mnt/plugins/ -r
	mkdir -p /usr/ikuai/www/static/css/fonts
	ln -s $INSTALL_DIR/data/element-icons.ttf /usr/ikuai/www/static/css/fonts/element-icons.ttf
	ln -s $INSTALL_DIR/data/element.css.gz /usr/ikuai/www/static/css/element.css.gz
	ln -s $INSTALL_DIR/data/element.js.gz /usr/ikuai/www/static/js/element.js.gz
	ln -s $INSTALL_DIR/data/plugin.js.gz /usr/ikuai/www/static/js/plugin.js.gz
	ln -s /etc/mnt/plugins/configs/img /usr/ikuai/www/plugins/
	ln -s ./$(basename $(ls /usr/ikuai/www/static/css/app.*.css.gz)) /usr/ikuai/www/static/css/plugin.css.gz
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/pgstore.sh /usr/ikuai/function/plugin_pgstore
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

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
