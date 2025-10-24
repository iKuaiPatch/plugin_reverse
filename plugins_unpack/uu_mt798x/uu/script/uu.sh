#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")

start(){

if [ -f /etc/mnt/uu/start ];then

	if killall -q -0 uuplugin ;then
		local status=1
		return
	fi

	uuplugin=`ps|grep "uuplugin"|grep -v "grep" |wc -l`
	if [ $uuplugin -eq 0 ];then
		sh $plugin_dir/../data/uu_install.sh openwrt $(uname -m) >/dev/null &
	fi

fi


}


uu_start(){
echo "uu" >/tmp/uu.log
if killall -q -0 uuplugin ;then
for pid in $(ps | grep "uuplugin_monitor" | grep -v "grep" | awk '{print $1}'); do
kill -9 $pid
done

for pid in $(ps | grep "uuplugin" | grep -v "grep" | awk '{print $1}'); do
kill -9 $pid
done

rm /etc/mnt/uu/start
return
fi


if [ -f /usr/sbin/uu/uuplugin_monitor.sh ];then
	/bin/sh /usr/sbin/uu/uuplugin_monitor.sh >/dev/null &
fi
mkdir /etc/mnt/uu -p
echo "1" >/etc/mnt/uu/start
start

}





stop(){
for pid in $(ps | grep "uuplugin_monitor" | grep -v "grep" | awk '{print $1}'); do
kill -9 $pid
done

for pid in $(ps | grep "uuplugin" | grep -v "grep" | awk '{print $1}'); do
kill -9 $pid
done
rm /usr/sbin/uu -r
rm /etc/mnt/uu -r
}

show(){
    Show __json_result__
}

__show_status(){
if killall -q -0 uuplugin ;then
	local status=1
else
	local status=0
fi

uuplugin=`ps|grep "uuplugin"|grep -v "grep" |wc -l`
if [ $uuplugin -gt 0 ];then
	local status=1
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

