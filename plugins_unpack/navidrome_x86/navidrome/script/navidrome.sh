#!/bin/bash /etc/ikcommon 

script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")



start(){


if [ ! -f /etc/mnt/navidrome ];then
return
fi


if [ ! -f /etc/log/chroot/navidrome/data/navidrome ];then
mkdir /etc/log/chroot/navidrome/ -p
cp $plugin_dir/../data /etc/log/chroot/navidrome/ -r
chmod +x /etc/log/chroot/navidrome/data/navidrome
rm $plugin_dir/../data/* -rf
else
rm $plugin_dir/../data/* -rf
fi

if [ -f $plugin_dir/../data/navidrome ];then
rm $plugin_dir/../data/navidrome -f
fi


if killall -q -0 navidrome;then
	return
fi
sh $plugin_dir/chroot_mount.sh >/dev/null &

if [ ! -d "/etc/log/chroot/etc" ];then
mkdir /etc/log/chroot/etc
fi

cp /etc/resolv.conf /etc/log/chroot/etc/resolv.conf
cp /etc/hosts /etc/log/chroot/etc/hosts


if [ ! -d "/etc/log/chroot/etc/hosts.d"]; then
mkdir -p "/etc/log/chroot/etc/hosts.d"
fi

cp /etc/hosts.d/* /etc/log/chroot/etc/hosts.d/

if [ ! -f "/etc/log/chroot/etc/ssl/certs/ca-certificates.crt" ];then
mkdir -p /etc/log/chroot/etc/ssl/certs
cp /etc/ssl/certs/ca-certificates.crt /etc/log/chroot/etc/ssl/certs/ca-certificates.crt
fi


if [ ! -f /etc/log/chroot/lib/libgcc_s.so.1 ];then
mkdir -p /etc/log/chroot/lib
cp /lib/libgcc_s.so.1 /etc/log/chroot/lib/libgcc_s.so.1
fi

if [ ! -f /etc/log/chroot/lib/libc.so.0 ];then
cp /lib/libc.so.0 /etc/log/chroot/lib/libc.so.0
fi
if [ ! -f /etc/log/chroot/lib/ld64-uClibc.so.0 ];then
cp /lib/ld64-uClibc.so.0 /etc/log/chroot/lib/ld64-uClibc.so.0
fi

if [ ! -f /etc/log/chroot/usr/bin/env ];then
mkdir -p /etc/log/chroot/usr/bin
cp /usr/bin/env /etc/log/chroot/usr/bin/env
fi
echo "start-chroot" >>/tmp/navidrome.log

chroot /etc/log/chroot  /navidrome/data/navidrome  --musicfolder "/disk_user" >/dev/null &


}


stop(){
killall navidrome
rm /etc/mnt/navidrome
}



navidrome_start(){

echo "navidrome_start" >>/tmp/navidrome.log
if killall -q -0 navidrome;then
	killall navidrome
	return
fi

if [ ! -f /etc/mnt/navidrome ];then
echo "1" >/etc/mnt/navidrome
fi

start
   
}

show()
{
    Show __json_result__
}


__show_status()
{
if killall -q -0 navidrome ;then
	
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
