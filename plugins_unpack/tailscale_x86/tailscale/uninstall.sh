#!/bin/bash 
PLUGIN_NAME="tailscale"
plugin_link=`readlink $BASH_SOURCE`
plugin_dir=`dirname $plugin_link`
plugin_dir=$plugin_dir
install()
{
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME

	ln -sf $INSTALL_DIR/script/tailscale.sh         /usr/ikuai/function/plugin_tailscale

}

__uninstall()
{
	killall $PLUGIN_NAME
	killall tailscaled
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
    rm $plugin_dir/../../../$PLUGIN_NAME -r
	rm /etc/log/ikipk/$PLUGIN_NAME -r -f
	rm /usr/sbin/tailscaled
	rm /usr/sbin/tailscale
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
