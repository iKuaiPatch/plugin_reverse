#!/bin/bash /etc/ikcommon 

script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")

md5sum $plugin_dir/../data/frpc | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit

if [ ! -f /usr/bin/frpc ];then
chmod +x $plugin_dir/../data/frpc
ln -fs $plugin_dir/../data/frpc /usr/bin/frpc
fi

# 读取某个键的值
# 参数: section 键名
CONFIG_FILE="/etc/mnt/frpc.ini"

read_ini_value() {
local section=$1
local key=$2
awk -F ' = ' -v section="[$section]" -v key="$key" '
$0 ~ section {found_section=1}
found_section && $1 == key {print $2; exit}
' "$CONFIG_FILE"
}

# 修改某个键的值
# 参数: section 键名 值
update_ini_value() {
local section=$1
local key=$2
local value=$3
sed -i "/\[$section\]/,/^$/s/^$key.*/$key = $value/" "$CONFIG_FILE"
echo "$key 已更新为 $value"
}


start() {

if [ -f /tmp/frpc_file.log ];then
	return
fi

if killall -q -0 frpc ; then
	killall frpc
	return
fi

if [ ! -f /etc/mnt/frpc.ini ];then
	return		
fi

if [ ! -f /usr/bin/frpc ]; then
	filedon
fi

	sed -i '/localPath/d' /etc/mnt/frpc.ini
	sed -i 's|log_file = .*|log_file = /tmp/log/frpc.log|' /etc/mnt/frpc.ini
	
	ln -s /etc/mnt/frpc.ini  /usr/ikuai/www/frpc.txt



while true
do
if ping -W 2 -c1 qq.com >/tmp/null;then
break
else
if ping -W 2 -c1 163.com >/tmp/null;then
break
else
sleep 10
if ping -W 2 -c1 baidu.com >/tmp/null;then
break
else
sleep 10
fi
fi
fi
done
	frpc -c /etc/mnt/frpc.ini >/dev/dell &

}



stop(){
    killall frpc
}

disable(){
    killall frpc
    rm /etc/mnt/frpc.ini
}

update_config(){
    local server="$1"
    local vkey="$2"
    local password="$3"
    local target="$4"
    local local_type="$5"


	server=$(echo "$server" | sed 's/%20/-/g')
	vkey=$(echo "$vkey" | sed 's/%20/-/g')
	local_type=$(echo "$local_type" | sed 's/%20/-/g')
	target=$(echo "$target" | sed 's/%20/-/g')
	
	
	
	
    echo "${server}" > /etc/mnt/frpc.config
    echo "${vkey}" >> /etc/mnt/frpc.config
    echo "${password}" >> /etc/mnt/frpc.config
    echo "${target}" >> /etc/mnt/frpc.config
    echo "${local_type}" >> /etc/mnt/frpc.config

    echo "配置文件已更新："
    cat /etc/mnt/frpc.config
    if killall -q -0 frpc ; then
        killall frpc
    fi
    start
}



config(){

 if [ -f /tmp/iktmp/import/file ]; then
   filesize=$(stat -c%s "/tmp/iktmp/import/file")
   echo "$filesize" >>/tmp/frpcconfig.log
   if [ $filesize -lt 524288 ]; then

			rm /etc/mnt/frpc.ini
			mv /tmp/iktmp/import/file /etc/mnt/frpc.ini
			echo "ok" >>/tmp/frpcconfig.log
			killall frpc
			start
	
   fi
   
 fi

}


show(){
    Show __json_result__
}

__show_status(){
    if killall -q -0 frpc ; then
        local status=1
    else
        local status=0
    fi
	
	if [ ! -f /usr/bin/frpc ];then
		local status=3
	fi
	
	if [  -f /tmp/frpc_file.log ];then
		local status=2
	fi
    json_append __json_result__ status:int
}

__show_config(){

plugin_link=`readlink $BASH_SOURCE`
plugin_dir=`dirname $plugin_link`
plugin_dir=$plugin_dir

if [ ! -f /usr/ikuai/www/frpc.txt ];then
ln -s $plugin_dir/../script/frpc.ini  /usr/ikuai/www/frpc.txt
fi

local server_addr=$(read_ini_value "common" "server_addr")
local server_port=$(read_ini_value "common" "server_port")
local admin_port=$(read_ini_value "common" "admin_port")

if [ ! -f /tmp/frpc.version ];then
frpc -v >/tmp/frpc.version
fi
version=`cat /tmp/frpc.version`

    json_append __json_result__ server_addr:str
    json_append __json_result__ server_port:str
    json_append __json_result__ admin_addr:str
    json_append __json_result__ admin_user:str
    json_append __json_result__ admin_pwd:str
	json_append __json_result__ admin_port:str
	json_append __json_result__ version:str

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
