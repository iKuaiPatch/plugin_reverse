#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


if [ ! -f /etc/machine-id ];then

	if [ ! -f /etc/mnt/ikuai/easytier/machine-id ];then

		cat /sys/class/dmi/id/product_uuid  > /etc/mnt/ikuai/easytier/machine-id

	fi

ln -s /etc/mnt/ikuai/easytier/machine-id /etc/machine-id 

fi



if [ ! -d /etc/mnt/ikuai/easytier ];then

mkdir /etc/mnt/ikuai/easytier -p

fi

if [ ! -f /usr/sbin/easytier-core ];then

chmod +x $plugin_dir/../data/easytier-core
ln -s $plugin_dir/../data/easytier-core /usr/sbin/easytier-core

fi



start(){


if [ ! -f /etc/mnt/ikuai/easytier/start ];then

return

fi

	if killall -q -0 easytier-core;then
		return
    fi

if [ -f /etc/mnt/ikuai/easytier/easytier.ymal ];then

easytier-core -c /etc/mnt/ikuai/easytier/easytier.ymal >/dev/null &

return
fi



if [ -f /etc/mnt/ikuai/easytier/easytier.usr ];then
local usrname=`cat /etc/mnt/ikuai/easytier/easytier.usr`

	if [ -f /etc/mnt/ikuai/easytier/easytier.ser ];then
		local server=`cat /etc/mnt/ikuai/easytier/easytier.ser`
		easytier-core  --config-server udp://$server:22020/$usrname >/dev/null &
		
		else
		easytier-core  --config-server $usrname >/dev/null &
		
	fi

fi



}


EasyTier_start(){

if killall -q -0 easytier-core;then
	killall easytier-core
	rm /etc/mnt/ikuai/easytier/start -f
	return
fi

if [ -f /usr/sbin/easytier-core ];then
	echo "1" >/etc/mnt/ikuai/easytier/start
	start	
fi

}

stop(){
killall easytier-core
}

config(){

 if [ -f /tmp/iktmp/import/file ]; then

	mv /tmp/iktmp/import/file /etc/mnt/ikuai/easytier/easytier.ymal
	killall easytier-core
	start

   
 fi

}

update_config(){



if [ -n "$token" ];then
echo $token >/etc/mnt/ikuai/easytier/easytier.usr
rm /etc/mnt/ikuai/easytier/easytier.ymal -f
fi


if [ -n "$server" ];then
echo $server >/etc/mnt/ikuai/easytier/easytier.ser
rm /etc/mnt/ikuai/easytier/easytier.ymal -f
else
rm /etc/mnt/ikuai/easytier/easytier.ser -f
fi

	if killall -q -0 easytier-core;then
		killall easytier-core
    fi
start
}


show(){
    Show __json_result__
}

__show_status(){
local status=0

if killall -q -0 easytier-core ;then
	local status=1

else
	local status=0
fi

if [ -f /etc/mnt/ikuai/easytier/easytier.usr ];then
token=`cat /etc/mnt/ikuai/easytier/easytier.usr`

fi

json_append __json_result__ status:int
json_append __json_result__ token:str



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
