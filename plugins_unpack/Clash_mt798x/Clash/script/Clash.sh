#!/bin/bash /etc/ikcommon
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")

ShellCrash=`cat "/etc/setup/setup.other"|grep "ShellCrash"|wc -l`

export OLDPWD='/etc/log/ShellCrash'
export CRASHDIR='/etc/log/ShellCrash'
alias crash='sh /etc/log/ShellCrash/menu.sh'
alias clash='sh /etc/log/ShellCrash/menu.sh'

if [ $ShellCrash -eq 0 ];then
sed -i "/q)/i\6)" /etc/setup/setup.other
sed -i "/q)/i\echo \"\"" /etc/setup/setup.other
sed -i "/q)/i\export OLDPWD='/etc/log/ShellCrash'" /etc/setup/setup.other
sed -i "/q)/i\export CRASHDIR='/etc/log/ShellCrash'" /etc/setup/setup.other
sed -i "/q)/i\sh /etc/log/ShellCrash/menu.sh" /etc/setup/setup.other
sed -i "/q)/i\;;" /etc/setup/setup.other
fi
clash_export=`cat /etc/profile|grep "clash" |wc -l`
if [ $clash_export -eq 0 ];then
echo "export OLDPWD='/etc/log/ShellCrash'" >>/etc/profile
echo "export CRASHDIR='/etc/log/ShellCrash'" >>/etc/profile
echo "alias crash='sh /etc/log/ShellCrash/menu.sh'" >>/etc/profile
echo "alias clash='sh /etc/log/ShellCrash/menu.sh'" >>/etc/profile
fi

	chmod +x /etc/log/ShellCrash/task/task.sh
	chmod +x /etc/log/ShellCrash/*

dns_clash(){

dns_no=`cat /etc/log/ShellCrash/configs/ShellCrash.cfg |grep "dns_no"|grep "已禁用"|wc -l`


	
	if [ $dns_no -eq 0 ];then
		#禁用
		echo "dns_no=已禁用" >>/etc/log/ShellCrash/configs/ShellCrash.cfg
		sh /etc/log/ShellCrash/menu.sh -s stop
		sh /etc/log/ShellCrash/menu.sh -s start >/dev/null &
		
	else
		#启用
	sed -i '/dns_no=已禁用/d' /etc/log/ShellCrash/configs/ShellCrash.cfg
	sh /etc/log/ShellCrash/menu.sh -s stop
	sh /etc/log/ShellCrash/menu.sh -s start >/dev/null &
		
	fi
	

}


dns_name_clash(){

sniffer=`cat /etc/log/ShellCrash/configs/ShellCrash.cfg |grep "sniffer"|grep "已启用"|wc -l`


	
	if [ $sniffer -eq 0 ];then
		#启用
		echo "sniffer=已启用" >>/etc/log/ShellCrash/configs/ShellCrash.cfg
		sh /etc/log/ShellCrash/menu.sh -s stop
		sh /etc/log/ShellCrash/menu.sh -s start >/dev/null &
		
	else
		#禁用
	sed -i '/sniffer=已启用/d' /etc/log/ShellCrash/configs/ShellCrash.cfg
	sh /etc/log/ShellCrash/menu.sh -s stop
	sh /etc/log/ShellCrash/menu.sh -s start >/dev/null &
		
	fi


}



start(){


plugin_link=`readlink $BASH_SOURCE`
plugin_dir=`dirname $plugin_link`
plugin_dir=$plugin_dir
export OLDPWD='/etc/log/ShellCrash'
export CRASHDIR='/etc/log/ShellCrash'
dns_config=0

if [ ! -d /etc/log/ShellCrash ];then
	tar -xvf $plugin_dir/../data/ShellCrash.tar  -C /etc/log
	chmod +x /etc/log/ShellCrash/task/task.sh
	chmod +x /etc/log/ShellCrash/*
	rm $plugin_dir/../data/ShellCrash.tar
	else
	rm $plugin_dir/../data/ShellCrash.tar
fi

if [ ! -f /etc/log/ShellCrash/CrashCore.tar.gz ];then
	mv $plugin_dir/../data/CrashCore.tar.gz /etc/log/ShellCrash/CrashCore.tar.gz
	else
	rm $plugin_dir/../data/ShellCrash.tar
fi


if [ ! -d /etc/log/ShellCrash/jsons ];then
mkdir /etc/log/ShellCrash/jsons -p
fi


if [ ! -f /etc/log/ShellCrash/config.yaml ];then
sh /etc/log/ShellCrash/start.sh get_core_config >/tmp/clashSubupdate.log &
sleep 5
fi

sh /etc/log/ShellCrash/menu.sh -s start >/dev/null &

tunip=`iptables -vnL OUTPUT --line-number|grep "198.18.0"|wc -l`
if [ $tunip -gt 0 ];then
iptables -D INPUT -d 198.18.0.0/30 -j DROP
iptables -D OUTPUT -d 198.18.0.0/30 -j DROP
iptables -D INPUT -d 198.18.0.0/30 -j DROP
iptables -D OUTPUT -d 198.18.0.0/30 -j DROP
fi

tunip=`iptables -vnL IUTPUT --line-number|grep "198.18.0"|wc -l`
if [ $tunip -gt 0 ];then
iptables -D INPUT -d 198.18.0.0/30 -j DROP
iptables -D OUTPUT -d 198.18.0.0/30 -j DROP
iptables -D INPUT -d 198.18.0.0/30 -j DROP
iptables -D OUTPUT -d 198.18.0.0/30 -j DROP
fi



}

Clash_start(){

plugin_link=`readlink $BASH_SOURCE`
plugin_dir=`dirname $plugin_link`
plugin_dir=$plugin_dir
export OLDPWD='/etc/log/ShellCrash'
export CRASHDIR='/etc/log/ShellCrash'
dns_config=0
if killall -q -0 CrashCore ;then
	local status=1
	#Clash_dns

	if [ $dns_config -eq 1 ];then
		sh /etc/log/ShellCrash/menu.sh -s start >/dev/null &
	fi

else

start

fi

}

stop(){
export OLDPWD='/etc/log/ShellCrash'
export CRASHDIR='/etc/log/ShellCrash'
sh /etc/log/ShellCrash/menu.sh -s stop >/dev/null &

}

show(){
    Show __json_result__
}

__show_status(){
if killall -q -0 CrashCore ;then
	local status=1
else
	local status=0
fi
	json_append __json_result__ status:int
}

__show_config(){

dns_no=`cat /etc/log/ShellCrash/configs/ShellCrash.cfg |grep "dns_no"|grep "已禁用"|wc -l`
. /etc/log/ShellCrash/configs/ShellCrash.cfg
json_append __json_result__ start_old:str
json_append __json_result__ versionsh_l:str
json_append __json_result__ update_url:str
json_append __json_result__ userguide:int
json_append __json_result__ redir_mod:str
json_append __json_result__ dns_nameserver:str
json_append __json_result__ dns_fallback:str
json_append __json_result__ crashcore:str
json_append __json_result__ core_v:str
json_append __json_result__ ipv6_redir:str
json_append __json_result__ ipv6_support:str
json_append __json_result__ cn_ipv6_route:str
json_append __json_result__ dns_mod:str
json_append __json_result__ cn_ip_route:str
json_append __json_result__ hostdir:str
json_append __json_result__ Https:str
json_append __json_result__ Url:str
json_append __json_result__ china_ip_list_v:int
json_append __json_result__ china_ipv6_list_v:int
json_append __json_result__ dns_no:str
json_append __json_result__ sniffer:str
echo "show config: ${__json_result__}" >> /tmp/json_result.log

}



update_config_value() {

echo "key=${key}"
echo "new_value=${new_value}"

if [ -z "$key" ] || [ -z "$new_value" ]; then
	echo "Key or value is missing"
	return 1
fi

#Clash_start


# 对特殊字符进行转义
# new_value=$(echo "$new_value" | sed 's/[\/&]/\\&/g')
# 替换指定键的值，而不修改键的名称


sed -i '/Url=/d' /etc/log/ShellCrash/configs/ShellCrash.cfg
echo "Url='${new_value}'" >> /etc/log/ShellCrash/configs/ShellCrash.cfg



sh /etc/log/ShellCrash/start.sh get_core_config >/tmp/clashSubupdate.log &
sleep 5

sh /etc/log/ShellCrash/menu.sh -s start >/dev/null &



}


clear_link(){

sed -i '/Url=/d' /etc/log/ShellCrash/configs/ShellCrash.cfg
rm /etc/log/ShellCrash/yamls/config.yaml -rf
rm /tmp/ShellCrash/* -rf


if [ -d /etc/log/IPK/socks5 ];then

	if [ -f /etc/log/ShellCrash/yamls/proxies.yaml ];then

		if killall -q -0 CrashCore ;then
		sed -i "/name: iKuai_/d" /tmp/ShellCrash/config.yaml
		

		
				if ! grep -q "^proxies:" /tmp/ShellCrash/config.yaml; then

						if ! grep -q "^proxy-groups:" /tmp/ShellCrash/config.yaml; then
									# 没找到proxy-groups:写入入proxies:
							echo 'proxies:' >> /tmp/ShellCrash/config.yaml
							
							else
									# 找到proxy-groups:行并在其上方插入proxies:
							sed -i '/^proxy-groups:/i\proxies:' /tmp/ShellCrash/config.yaml
						fi
					
				fi


				sed 's/^/  /' "/etc/log/ShellCrash/yamls/proxies.yaml" > /tmp/proxies_indented
				sed -i "/^proxies:/r /tmp/proxies_indented" /tmp/ShellCrash/config.yaml
				cat /etc/log/ShellCrash/yamls/rules.yaml >>/tmp/ShellCrash/config.yaml
				curl -X PUT "http://127.0.0.1:9999/configs" -d '{"path": "/tmp/ShellCrash/config.yaml"}'
		fi

	fi
	
fi
}

__show_dconfig(){

    cp /etc/log/ShellCrash/yamls/config.yaml /tmp/iktmp/export/config.yaml
	configfile=config.yaml
	json_append __json_result__ configfile:str
	
}

config(){

file_type=`echo $Filename|awk -F "." '{print $NF}'`
echo $file_type >/tmp/classh.log
 if [ -f /tmp/iktmp/import/file ]; then

	if [ "$file_type" == "jsons" ];then
		mv /tmp/iktmp/import/file /etc/log/ShellCrash/jsons/$Filename
	else
		mv /tmp/iktmp/import/file /etc/log/ShellCrash/yamls/$Filename
	fi

 fi
	
}


update_yaml() {

	if [ "$fileType" = "yaml" ]; then
		mv /tmp/iktmp/import/file /etc/log/ShellCrash/yamls/config.yaml
	elif [ "$fileType" = "json" ]; then
		mv /tmp/iktmp/import/file /etc/log/ShellCrash/jsons/config.json
	else
		echo "文件格式不正确!"
		return 1
	fi

	# 如果已经启动，则重新启动
	PID=$(pidof CrashCore | awk '{print $NF}')
	[ -n "$PID" ] || return 0
	
	start && return 0
	
	echo "更新订阅地址失败"
	return 1
}

download_yaml() {
	cp /etc/log/ShellCrash/yamls/config.yaml /tmp/iktmp/export/
}

download_json() {
	cp /etc/log/ShellCrash/jsons/config.json /tmp/iktmp/export/
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

