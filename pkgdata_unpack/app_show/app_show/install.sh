#!/bin/bash

install()
{
	ln -sf $INSTALL_DIR/app_show_client /usr/sbin/app_show_client
	ln -sf $INSTALL_DIR/app_show_server /usr/sbin/app_show_server
	ln -sf $INSTALL_DIR/app_show.sh /usr/ikuai/function/app_show

}


uninstall()
{
	killall app_show_server >/dev/null 2>&1
	rm /usr/sbin/app_show_client
	rm /usr/sbin/app_show_server
	rm /usr/ikuai/function/app_show
}

procname=$(basename $BASH_SOURCE)
if [ "$procname" = "install.sh" ];then
	install
else
	uninstall
fi

