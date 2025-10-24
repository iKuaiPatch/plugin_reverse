#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


#plugin_dir="$(cd "$(dirname "$0")" && pwd)"


md5sum $plugin_dir/../data/vlmcsd | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit


start(){
	killall vlmcsd
	if [ ! -f /sbin/vlmcsd ];then
	chmod +x $plugin_dir/../data/vlmcsd
	ln -s $plugin_dir/../data/vlmcsd /sbin/vlmcsd
	fi
	if [ ! -f /etc/mnt/vlmcsd.ini ];then
		cp $plugin_dir/../data/vlmcsd.ini /etc/mnt/vlmcsd.ini
	fi

	if [ ! -f /usr/ikuai/www/vlmcsd.txt ];then
		ln -s /etc/mnt/vlmcsd.ini /usr/ikuai/www/vlmcsd.txt
	fi

	vlmcsd_number=`iptables -vnL INPUT --line-number|grep "1688"|wc -l`
	if [ $vlmcsd_number -eq 0 ];then
		iptables -I INPUT -p tcp --dport 1688 -j ACCEPT
	fi
	vlmcsd -i /etc/mnt/vlmcsd.ini -L 0.0.0.0:1688 >>/tmp/vlmcsd.log &

}


Vlmcsd_start(){

	if [ ! -f /etc/mnt/vlmcsd.ini ];then
		cp $plugin_dir/../data/vlmcsd.ini /etc/mnt/vlmcsd.ini
	fi

start
}

stop(){
killall vlmcsd
rm /etc/mnt/vlmcsd.ini
echo "stop"  >>/tmp/vlmcsd.logs
}


config(){

 if [ -f /tmp/iktmp/import/file ]; then
   filesize=$(stat -c%s "/tmp/iktmp/import/file")
   if [ $filesize -lt 524288 ]; then
	mv /tmp/iktmp/import/file /etc/mnt/vlmcsd.ini
	Vlmcsd_start
   fi
   
 fi

}

show(){
    local __filter=$(sql_auto_get_filter)
    local __order=$(sql_auto_get_order)
    local __limit=$(sql_auto_get_limit)
    local __where="$__filter $__order $__limit"
    Show __json_result__
}

__show_status(){
local status=0
if [ ! -f /usr/ikuai/www/vlmcsd.txt ];then

	ln -s /etc/mnt/vlmcsd.ini /usr/ikuai/www/vlmcsd.txt
fi
if killall -q -0 vlmcsd ;then
	local status=1
else
	local status=0
fi
json_append __json_result__ status:int
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
      ;;
esac
