#!/bin/bash /etc/ikcommon 

script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")



start(){



if [ -d /usr/ikuai/www/plugins/socks5 ];then
return
fi 

if [ ! -f /etc/mnt/rclone/start ];then
return
fi




if [ ! -d /etc/log/chroot ];then
mkdir /etc/log/chroot/rclone -p
cp $plugin_dir/../data /etc/log/chroot/rclone -r
chmod +x /etc/log/chroot/rclone/data/rclone
fi


if [ ! -f /etc/log/chroot/rclone/data/rclone ];then
mkdir /etc/log/chroot/rclone/ -p
cp $plugin_dir/../data /etc/log/chroot/rclone/ -r
chmod +x /etc/log/chroot/rclone/data/rclone
fi

if [ -f $plugin_dir/../data/rclone ];then
rm $plugin_dir/../data/rclone -f
fi


if killall -q -0 rclone;then
	return
fi

if [ ! -f /etc/mnt/rclone/user ];then
user=admin
else
user=`cat /etc/mnt/rclone/user`
fi

if [ ! -f /etc/mnt/rclone/password ];then
password=123456
else
password=`cat /etc/mnt/rclone/password`
fi

if [ ! -f /etc/mnt/rclone/port ];then
port=5572
else
port=`cat /etc/mnt/rclone/port`
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

chroot /etc/log/chroot /rclone/data/rclone rcd --rc-web-gui --rc-web-gui-no-open-browser --rc-addr=:$port --rc-user=$user --rc-pass=$password --log-level=NOTICE --cache-dir=/rclone/data/rclone_cache --rc-allow-origin="https://rclone.github.io" >/dev/null &



}


stop(){
killall rclone
rm /etc/mnt/rclone/start -f
rm /etc/mnt/rclone -rf

}



rclone_start(){

if [ -d /usr/ikuai/www/plugins/socks5 ];then
return
fi 

if killall -q -0 rclone;then
	killall rclone
	rm  /etc/mnt/rclone/start -f
	return
fi

if [ ! -d /etc/mnt/rclone ];then
mkdir /etc/mnt/rclone
echo "1" >/etc/mnt/rclone/start
fi

start
   
}




update_config(){

if [ -n "$user" ];then
echo $user >/etc/mnt/rclone/user
fi

if [ -n "$password" ];then
echo $password >/etc/mnt/rclone/password
fi

if [ -n "$port" ];then
echo $port >/etc/mnt/rclone/port
fi

killall rclone
start
}

show()
{
    Show __json_result__
}


__show_status()
{
if killall -q -0 rclone ;then
	
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
