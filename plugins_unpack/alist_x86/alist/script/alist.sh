#!/bin/bash /etc/ikcommon 

script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


md5sum $plugin_dir/../data/alist | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit

if [ ! -f /tmp/app/alist/alist ];then
mkdir -p /tmp/app/alist
chmod +x $plugin_dir/../data/alist
ln -fs $plugin_dir/../data/alist /tmp/app/alist/alist
fi


start(){


if [ ! -d /etc/mnt/alist/data ];then
	return
fi

/tmp/app/alist/alist server --data /etc/mnt/alist/data --log-std >/dev/null &

}

alist_passwd(){

if [ ! -f /tmp/app/alist/alist ];then
return
fi

if [ ! -f /etc/mnt/alist/data/data.db ];then
return
fi
/tmp/app/alist/alist  --data /etc/mnt/alist/data admin set admin

}

alist_start(){


if killall -q -0 alist;then
	killall alist
	return
fi

if [ ! -d /etc/mnt/alist/data ];then
	mkdir /etc/mnt/alist/data -p
fi

/tmp/app/alist/alist server --data /etc/mnt/alist/data --log-std >/dev/null &

}

stop(){
killall alist
rm /etc/mnt/alist -r
}

config(){
echo "1" >>/tmp/alistconfig.log
 if [ -f /tmp/iktmp/import/file ]; then
   filesize=$(stat -c%s "/tmp/iktmp/import/file")
   echo "$filesize" >>/tmp/alistconfig.log
   if [ $filesize -lt 524288 ]; then
	   if [ -f /etc/mnt/alist/conf/alist.conf ];then
			rm /etc/mnt/alist/conf/alist.conf
			mv /tmp/iktmp/import/file /etc/mnt/alist/conf/alist.conf
			echo "ok" >>/tmp/alistconfig.log
			killall alist
			start
		fi
   fi
   
 fi

}


show(){

    Show __json_result__
}

__show_status(){
local status=0

if [ ! -f /tmp/app/alist/alist ];then
local status=3
fi

if [ -f /tmp/alist_file.log ];then
local status=2
fi

if killall -q -0 alist ;then
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
