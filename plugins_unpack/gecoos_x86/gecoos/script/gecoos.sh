#!/bin/bash /etc/ikcommon 

script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


md5sum $plugin_dir/../data/ac_linux_amd64 | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit

if [ ! -f /sbin/ac_linux_amd64 ];then
chmod +x $plugin_dir/../data/ac_linux_amd64
ln -fs $plugin_dir/../data/ac_linux_amd64 /sbin/ac_linux_amd64
fi




start(){
if [ ! -d /etc/mnt/ac_linux ];then
return
fi

if killall -q -0 ac_linux_amd64 ;then
return
else
/sbin/ac_linux_amd64 -p 60650 -f /tmp/ac_linux/ -dbpath /etc/mnt/ac_linux -token 1 -lang zh >/tmp/ac_linux.log &
fi

   
}


gecoos_stop(){
killall ac_linux_amd64

}

gecoos_start(){

if [ ! -d /etc/mnt/ac_linux ];then
mkdir /etc/mnt/ac_linux -p
mkdir /tmp/ac_linux -p
fi

if [ ! -d //tmp/ac_linux ];then
mkdir /tmp/ac_linux -p
fi

if killall -q -0 ac_linux_amd64;then
	killall ac_linux_amd64
else	
	/sbin/ac_linux_amd64 -p 60650 -f /tmp/ac_linux/ -dbpath /etc/mnt/ac_linux -token 1 -lang zh >/tmp/ac_linux.log &
fi
   




}

show()
{
    Show __json_result__
}


__show_status()
{
if killall -q -0 ac_linux_amd64 ;then
	local status=1
else
	local status=0
fi

if [ ! -f /sbin/ac_linux_amd64 ];then
	local status=2
fi
	json_append __json_result__ status:int
}



gecoos_disable(){
	gecoos_stop
	rm /etc/mnt/ac_linux  -rf
	rm /tmp/ac_linux -rf
	echo "禁用ac_linux_amd64成功" >>/tmp/gecoos.log
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
