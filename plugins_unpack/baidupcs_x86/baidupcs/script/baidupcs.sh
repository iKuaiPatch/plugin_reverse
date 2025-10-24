#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")




start(){

if [ ! -f /etc/mnt/baidupcs ];then
return
fi



if killall -q -0 baidupcs;then
	return
fi


if [ ! -d /etc/log/chroot ];then
mkdir /etc/log/chroot/baidupcs -p
cp $plugin_dir/../data /etc/log/chroot/baidupcs -r
chmod +x /etc/log/chroot/baidupcs/data/baidupcs
rm $plugin_dir/../data/* -rf
else
rm $plugin_dir/../data/* -rf
fi


if [ ! -f /etc/log/chroot/baidupcs/data/baidupcs ];then
mkdir /etc/log/chroot -p
mkdir /etc/log/chroot/baidupcs/data -p
cp $plugin_dir/../data/baidupcs  /etc/log/chroot/baidupcs/data/baidupcs
chmod +x /etc/log/chroot/baidupcs/data/baidupcs
fi

if [ -f $plugin_dir/../data/baidupcs ];then
rm $plugin_dir/../data/baidupcs -f
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


chroot /etc/log/chroot /baidupcs/data/baidupcs web env --port 5299 --access >/dev/null &
}

#NDMmVyQjNHT0ZiSVZ2aU56V2YwbVhFcjZNWkRtem51MlJod3ppNVhhNmRmRXBuSVFBQUFBJCQAAAAAAAAAAAEAAAAXvqs2zNq3ybLLxPEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJ3vImed7yJnZH



#mount --bind "/sbin" "/etc/log/chroot/sbin"
#mkdir /tmp/chroot/proc -p
#mount --bind "/proc" "/tmp/chroot/proc"



#mount --bind "/lib64" "/etc/log/chroot/lib64"



stop(){
killall baidupcs
rm /etc/mnt/baidupcs
}


bd_start(){

if killall -q -0 baidupcs;then
	killall baidupcs
	return
fi

if [ ! -f /etc/mnt/baidupcs ];then
echo "1" >/etc/mnt/baidupcs
fi

start


}



show(){
    Show __json_result__
}

__show_status(){
local status=0

if killall -q -0 baidupcs ;then
	local status=1

else
	local status=0
fi


if [ -f /etc/log/chroot/baidupcs/pcs_config.json ];then
config_file="/etc/log/chroot/baidupcs/pcs_config.json"
else
config_file="/etc/log/chroot/.config/BaiduPCS-Go/pcs_config.json"
fi

uid=$(jq '.baidu_user_list[0].uid' "$config_file")
name=$(jq -r '.baidu_user_list[0].name' "$config_file")
bduss=$(jq -r '.baidu_user_list[0].bduss' "$config_file")
max_parallel=$(jq '.max_parallel' "$config_file")
max_upload_parallel=$(jq '.max_upload_parallel' "$config_file")
max_download_load=$(jq '.max_download_load' "$config_file")
max_download_rate=$(jq '.max_download_rate' "$config_file")
max_upload_rate=$(jq '.max_upload_rate' "$config_file")
savedir=$(jq -r '.savedir' "$config_file")

json_append __json_result__ uid:str
json_append __json_result__ name:str
json_append __json_result__ bduss:str
json_append __json_result__ max_parallel:str
json_append __json_result__ max_upload_parallel:str
json_append __json_result__ max_download_load:str
json_append __json_result__ max_download_rate:str
json_append __json_result__ max_upload_rate:str
json_append __json_result__ savedir:str


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
