#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


md5sum $plugin_dir/../data/hbbs | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit
md5sum $plugin_dir/../data/hbbr | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit
md5sum $plugin_dir/../data/rustdesk-utils | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit

if [ ! -d /etc/mnt/ikuai/rustdesk ];then

mkdir /etc/mnt/ikuai/rustdesk -p

fi



if [ -f /etc/mnt/ikuai/rustdesk/id_ed25519 ];then
	cp /etc/mnt/ikuai/rustdesk/id_ed25519 $plugin_dir/../data/
fi

if [ -f /etc/mnt/ikuai/rustdesk/id_ed25519.pub ];then
	cp /etc/mnt/ikuai/rustdesk/id_ed25519.pub $plugin_dir/../data/
fi


start(){

if [ ! -f /etc/mnt/ikuai/rustdesk/start ];then
return
fi

if killall -q -0 hbbs || killall -q -0 hbbr; then
	return
fi


cd $plugin_dir/../data/
./hbbs >/dev/null &
./hbbr  >/dev/null &


if [ ! -f /etc/mnt/ikuai/rustdesk/id_ed25519 ];then
	cp  $plugin_dir/../data/id_ed25519 /etc/mnt/ikuai/rustdesk/id_ed25519
fi

if [ ! -f /etc/mnt/ikuai/rustdesk/id_ed25519.pub ];then
	cp  $plugin_dir/../data/id_ed25519.pub /etc/mnt/ikuai/rustdesk/id_ed25519.pub
fi


}


rustdesk_start(){



if killall -q -0 hbbs || killall -q -0 hbbr; then
		killall hbbs
		killall hbbr
		rm /etc/mnt/ikuai/rustdesk/start -f
	return
fi

echo "1" >/etc/mnt/ikuai/rustdesk/start
start	


}

stop(){
killall hbbs
killall hbbr
}

config(){

 if [ -f /tmp/iktmp/import/file ]; then

	mv /tmp/iktmp/import/file /etc/mnt/ikuai/easytier/easytier.ymal
	killall easytier-core
	start

   
 fi

}

update_config(){

start

}


show(){
    Show __json_result__
}

__show_status(){
local status=0

if killall -q -0 hbbs && killall -q -0 hbbr; then
    local status=1
else
    local status=0
fi


local token=`cat /etc/mnt/ikuai/rustdesk/id_ed25519.pub`

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
