#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")
Ttyd_start(){
if [ ! -f /bin/usr/ttyd ];then


	if [ ! -f /sbin/data/ttyd ];then

	ln -sf  $plugin_dir/../data/ttyd /usr/bin/ttyd

	ln -sf $plugin_dir/../data/libcrypto.so.1.1 /usr/lib/libcrypto.so.1.1
	ln -sf $plugin_dir/../data/libssl.so.1.1 /usr/lib/libssl.so.1.1
	ln -sf $plugin_dir/../data/libuv.so.1 /usr/lib/libuv.so.1
	ln -sf $plugin_dir/../data/libwebsockets.so.14 /usr/lib/libwebsockets.so.14

	else

		ln -sf /sbin/data/ttyd /usr/bin/ttyd

		ln -sf /sbin/data/libcrypto.so.1.1 /usr/lib/libcrypto.so.1.1
		ln -sf /sbin/data/libssl.so.1.1 /usr/lib/libssl.so.1.1
		ln -sf /sbin/data/libuv.so.1 /usr/lib/libuv.so.1
		ln -sf /sbin/data/libwebsockets.so.14 /usr/lib/libwebsockets.so.14
		rm $plugin_dir/../data -r

	fi
	
	
ttyd -c admin:ttyd -p 2222 -i 0.0.0.0  /etc/setup/rc >/dev/null &


fi


}

Ttyd_stop(){
killall ttyd

}

show(){
    local __filter=$(sql_auto_get_filter)
    local __order=$(sql_auto_get_order)
    local __limit=$(sql_auto_get_limit)
    local __where="$__filter $__order $__limit"
    Show __json_result__
}

__show_status(){
if killall -q -0 ttyd ;then
	local status=1
else
	local status=0
fi
	json_append __json_result__ status:int
}
