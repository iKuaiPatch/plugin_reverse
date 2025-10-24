#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


md5sum $plugin_dir/../data/frps | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit


if [ ! -f /usr/bin/frps ];then
chmod +x $plugin_dir/../data/frps
ln -fs $plugin_dir/../data/frps /usr/bin/frps
fi

# 读取某个键的值
# 参数: section 键名
CONFIG_FILE="/etc/mnt/frps.ini"

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

if [ ! -f /etc/mnt/frps.ini ];then
	return		
fi

if [ -f /tmp/frps_file.log ];then
	return
fi

if killall -q -0 frps ; then
	killall frps
	return
fi

	sed -i '/localPath/d' /etc/mnt/frps.ini
	sed -i 's|log_file = .*|log_file = /tmp/log/frps.log|' /etc/mnt/frps.ini
	
	ln -s /etc/mnt/frps.ini  /usr/ikuai/www/frps.txt

	frps -c /etc/mnt/frps.ini >/dev/dell &
echo "9" >>/tmp/frpsstart.log
}


frps_start() {

echo "1" >>/tmp/frpsstart.log
if [ ! -f /etc/mnt/frps.ini ];then
echo "2" >>/tmp/frpsstart.log
echo "[common]" > /etc/mnt/frps.ini
echo "bindPort = 7000" >> /etc/mnt/frps.ini
echo "dashboard_port = 7001" >> /etc/mnt/frps.ini
echo "dashboard_user = admin" >> /etc/mnt/frps.ini
echo "dashboard_pwd = admin	" >> /etc/mnt/frps.ini
fi
echo "3" >>/tmp/frpsstart.log
start

}


stop(){
    killall frps
}

disable(){
    killall frps
    rm /etc/mnt/frps.ini
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
	
	
	
	
    echo "${server}" > /etc/mnt/frps.config
    echo "${vkey}" >> /etc/mnt/frps.config
    echo "${password}" >> /etc/mnt/frps.config
    echo "${target}" >> /etc/mnt/frps.config
    echo "${local_type}" >> /etc/mnt/frps.config

    echo "配置文件已更新："
    cat /etc/mnt/frps.config
    if killall -q -0 frps ; then
        killall frps
    fi
    start
}



config(){

 if [ -f /tmp/iktmp/import/file ]; then
   filesize=$(stat -c%s "/tmp/iktmp/import/file")
   echo "$filesize" >>/tmp/frpsconfig.log
   if [ $filesize -lt 524288 ]; then

			rm /etc/mnt/frps.ini
			mv /tmp/iktmp/import/file /etc/mnt/frps.ini
			echo "ok" >>/tmp/frpsconfig.log
			killall frps
			start
	
   fi
   
 fi

}


show(){
    Show __json_result__
}

__show_status(){
    if killall -q -0 frps ; then
        local status=1
    else
        local status=0
    fi
	
	if [ ! -f /usr/bin/frps ];then
		local status=3
	fi
	
	if [  -f /tmp/frps_file.log ];then
		local status=2
	fi
    json_append __json_result__ status:int
}

__show_config(){

plugin_link=`readlink $BASH_SOURCE`
plugin_dir=`dirname $plugin_link`
plugin_dir=$plugin_dir

if [ ! -f /usr/ikuai/www/frps.txt ];then
ln -s $plugin_dir/../script/frps.ini  /usr/ikuai/www/frps.txt
fi

local server_addr=$(read_ini_value "common" "server_addr")
local server_port=$(read_ini_value "common" "bindPort")
local admin_port=$(read_ini_value "common" "dashboard_port")
local admin_user=$(read_ini_value "common" "dashboard_user")
local admin_pwd=$(read_ini_value "common" "dashboard_pwd")

if [ ! -f /tmp/frps.version ];then
frps -v >/tmp/frps.version
fi
version=`cat /tmp/frps.version`


    json_append __json_result__ server_addr:str
    json_append __json_result__ server_port:str
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
