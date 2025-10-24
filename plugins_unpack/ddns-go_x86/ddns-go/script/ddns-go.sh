#!/bin/bash /etc/ikcommon 

script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


if [ ! -d /etc/mnt/ikuai/app_config ];then
mdir -p /etc/mnt/ikuai/app_config
fi
start(){

if [ ! -f /etc/mnt/ikuai/app_config/ddns-go ];then
return
fi


if killall -q -0 ddns-go;then
	return
fi


if [ ! -d /etc/log/chroot ];then
mkdir /etc/log/chroot/ddns-go -p
cp $plugin_dir/../data /etc/log/chroot/ddns-go -r
chmod +x /etc/log/chroot/ddns-go/data/ddns-go
fi


if [ ! -f /etc/log/chroot/ddns-go/data/ddns-go ];then
mkdir /etc/log/chroot -p
mkdir /etc/log/chroot/ddns-go/data -p
cp $plugin_dir/../data/ddns-go  /etc/log/chroot/ddns-go/data/ddns-go
chmod +x /etc/log/chroot/ddns-go/data/ddns-go
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

chroot /etc/log/chroot /ddns-go/data/ddns-go -c /ddns-go/data/ddns_go_config.yaml >/dev/null &

}


ddns_start(){

if [ ! -f /etc/mnt/ikuai/app_config ];then
mkdir /etc/mnt/ikuai/app_config -p
fi

if killall -q -0 ddns-go ; then
	killall ddns-go
	rm /etc/mnt/ikuai/app_config/ddns-go
else

if [ ! -f /etc/mnt/ddns-go ];then
echo "1" >/etc/mnt/ikuai/app_config/ddns-go
fi

start


fi




}





stop(){
    killall ddns-go
}

disable(){
killall ddns-go
umount /etc/mnt/ddns-go
rm /etc/mnt/ikuai/app_config/ddns-go -rf
}

show(){

    Show __json_result__
}

__show_status(){
if killall -q -0 ddns-go ; then
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
