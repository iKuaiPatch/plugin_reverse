#!/bin/bash /etc/ikcommon

start()
{
	app_show_server
	return 0
}

stop()
{
	killall app_show_server >/dev/null 2>&1
}

