#!/bin/bash /etc/ikcommon 

script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


start(){

if [ ! -f /etc/mnt/lucky ];then
return
fi


if killall -q -0 lucky;then
	return
fi


if [ ! -d /etc/log/chroot ];then
mkdir /etc/log/chroot/lucky -p
cp $plugin_dir/../data /etc/log/chroot/lucky -r
chmod +x /etc/log/chroot/lucky/data/lucky
fi


if [ ! -f /etc/log/chroot/lucky/data/lucky ];then
mkdir /etc/log/chroot -p
mkdir /etc/log/chroot/lucky/data -p
cp $plugin_dir/../data/lucky  /etc/log/chroot/lucky/data/lucky
chmod +x /etc/log/chroot/lucky/data/lucky
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
if ! mount | grep -q "/etc/log/chroot/proc"; then
mkdir -p "/etc/log/chroot/proc"
mount --bind "/proc" "/etc/log/chroot/proc"
fi

chroot /etc/log/chroot /lucky/data/lucky -c /lucky/data/ >/dev/null &

}


lucky_start(){

if [  -d /etc/mnt/lucky ];then
rm /etc/mnt/lucky -rf
fi

if killall -q -0 lucky ; then
	killall lucky
	rm /etc/mnt/lucky
else

if [ ! -f /etc/mnt/lucky ];then
echo "1" >/etc/mnt/lucky
fi

start


fi




}





stop(){
    killall lucky
}

disable(){
killall lucky
umount /etc/mnt/lucky
rm /etc/mnt/lucky -rf
}

show(){

    Show __json_result__
}

__show_status(){
if killall -q -0 lucky ; then
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
