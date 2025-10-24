#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


start(){

cat /etc/release|grep "LINUX_VERSION"|awk -F "=" '{print $2}' >/etc/openwrt_version

if [ ! -d /tmp/data ];then
mkdir -p /tmp/data
fi

if [ -f /etc/mnt/xunyou/start ];then

	if killall -q -0 xunyou ;then
		local status=1
		return
	fi

	xunyou=`ps|grep "bin/xunyou"|grep -v "grep" |wc -l`
	if [ $xunyou -eq 0 ];then
		sh $plugin_dir/../data/xunyou_install.sh openwrt $(uname -m) -i lan1 >/dev/null &
	fi

fi


}


xunyou_start(){
echo "xunyou" >/tmp/xunyou.log

if killall -q -0 xunyou ;then
for pid in $(ps | grep "xunyou_daemon" | grep -v "grep" | awk '{print $1}'); do
kill -9 $pid
done
for pid in $(ps | grep "bin/xunyou" | grep -v "grep" | awk '{print $1}'); do
kill -9 $pid
done

rm /etc/mnt/xunyou/start
return
fi


if [ -f /tmp/xunyou/bin/xunyou ];then
	sh /tmp/xunyou/xunyou_daemon.sh start >/dev/null &
fi
mkdir /etc/mnt/xunyou -p
echo "1" >/etc/mnt/xunyou/start
start

}



stop(){

for pid in $(ps | grep "xunyou/xunyou" | grep -v "grep" | awk '{print $1}'); do
kill -9 $pid
done

for pid in $(ps | grep "bin/xunyou" | grep -v "grep" | awk '{print $1}'); do
kill -9 $pid
done
rm /tmp/data/xunyou -rf
rm /tmp/xunyou -rf
rm /etc/mnt/xunyou/start -rf

}

show(){
    Show __json_result__
}

__show_status(){
if killall -q -0 xunyou ;then
	local status=1
else
	local status=0
fi

if [ -f /tmp/xunyou/bin/xunyou ];then
local status=2
fi

xunyou=`ps|grep "xunyou_daemon"|grep -v "grep" |wc -l`
if [ $xunyou -gt 0 ];then
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

