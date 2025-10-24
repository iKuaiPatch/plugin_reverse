#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


ShellCrash=`cat "/etc/setup/setup.other"|grep "ShellCrash"|wc -l`
export OLDPWD='/tmp/log/ShellCrash'
export CRASHDIR='/tmp/log/ShellCrash'
alias crash='sh /tmp/log/ShellCrash/menu.sh'
alias clash='sh /tmp/log/ShellCrash/menu.sh'



tunip=`iptables -vnL OUTPUT --line-number|grep "198.18.0"|wc -l`
if [ $tunip -gt 0 ];then
iptables -D INPUT -d 198.18.0.0/30 -j DROP
iptables -D OUTPUT -d 198.18.0.0/30 -j DROP
iptables -D INPUT -d 198.18.0.0/30 -j DROP
iptables -D OUTPUT -d 198.18.0.0/30 -j DROP
fi

if [ $ShellCrash -eq 0 ];then
sed -i "/q)/i\6)" /etc/setup/setup.other
sed -i "/q)/i\echo \"\"" /etc/setup/setup.other
sed -i "/q)/i\export OLDPWD='/tmp/log/ShellCrash'" /etc/setup/setup.other
sed -i "/q)/i\export CRASHDIR='/tmp/log/ShellCrash'" /etc/setup/setup.other
sed -i "/q)/i\sh /tmp/log/ShellCrash/menu.sh" /etc/setup/setup.other
sed -i "/q)/i\;;" /etc/setup/setup.other
fi

clash_export=`cat /etc/profile|grep "clash" |wc -l`
if [ $clash_export -eq 0 ];then
echo "export OLDPWD='/tmp/log/ShellCrash'" >>/etc/profile
echo "export CRASHDIR='/tmp/log/ShellCrash'" >>/etc/profile
echo "alias crash='sh /tmp/log/ShellCrash/menu.sh'" >>/etc/profile
echo "alias clash='sh /tmp/log/ShellCrash/menu.sh'" >>/etc/profile
fi


sed -i 's#/etc/log#/tmp/log#g' /etc/profile

if [ ! -d /tmp/log/ShellCrash ];then
	tar -xvf $plugin_dir/../data/ShellCrash.tar  -C /etc/log
	else
	rm  $plugin_dir/../data/ShellCrash.tar
fi



if [ ! -d /etc/mnt/ShellCrash ];then
mkdir /etc/mnt/ShellCrash -p
cp /tmp/log/ShellCrash/configs /etc/mnt/ShellCrash/ -r
cp /tmp/log/ShellCrash/task /etc/mnt/ShellCrash/ -r
fi

rm /tmp/log/ShellCrash/configs -rf
rm /tmp/log/ShellCrash/task -rf
ln -s /etc/mnt/ShellCrash/configs /tmp/log/ShellCrash/
ln -s /etc/mnt/ShellCrash/task /tmp/log/ShellCrash/

chmod +x /tmp/log/ShellCrash/task/*
chmod +x /tmp/log/ShellCrash/*
echo '0' >>/tmp/clash.log



dns_clash(){

echo 'dns_clash' >>/tmp/clash.log
dns_no=`cat /tmp/log/ShellCrash/configs/ShellCrash.cfg |grep "dns_no"|grep "已禁用"|wc -l`


	
	if [ $dns_no -eq 0 ];then
		#禁用
		echo "dns_no=已禁用" >>/tmp/log/ShellCrash/configs/ShellCrash.cfg
		sh /tmp/log/ShellCrash/menu.sh -s stop
		sh /tmp/log/ShellCrash/menu.sh -s start >/dev/null &
		
	else
		#启用
	sed -i '/dns_no=已禁用/d' /tmp/log/ShellCrash/configs/ShellCrash.cfg
	sh /tmp/log/ShellCrash/menu.sh -s stop
	sh /tmp/log/ShellCrash/menu.sh -s start >/dev/null &
		
	fi
	

}
#local_proxy=已开启
#local_type=环境变量
#source /etc/profile > /dev/null
#export all_proxy=http://127.0.0.1:7890
#export ALL_PROXY=$all_proxy

dns_name_clash(){

echo 'dns_name_clash' >>/tmp/clash.log
sniffer=`cat /tmp/log/ShellCrash/configs/ShellCrash.cfg |grep "sniffer"|grep "已启用"|wc -l`

	if [ $sniffer -eq 0 ];then
		#启用
		echo "sniffer=已启用" >>/tmp/log/ShellCrash/configs/ShellCrash.cfg
		sh /tmp/log/ShellCrash/menu.sh -s stop
		sh /tmp/log/ShellCrash/menu.sh -s start >/dev/null &
		
	else
		#禁用
	sed -i '/sniffer=已启用/d' /tmp/log/ShellCrash/configs/ShellCrash.cfg
	sh /tmp/log/ShellCrash/menu.sh -s stop
	sh /tmp/log/ShellCrash/menu.sh -s start >/dev/null &
		
	fi


}


start(){


echo '1' >>/tmp/clash.log

export OLDPWD='/tmp/log/ShellCrash'
export CRASHDIR='/tmp/log/ShellCrash'
clash_update_url=`cat /etc/crontabs/root|grep "面板"|wc -l`
if [ $clash_update_url -eq 0 ];then

#echo '0 8 * * * /tmp/log/ShellCrash/task/task.sh 104 在每日的8点0分更新订阅并重启服务' >>/etc/crontabs/root
echo '*/10 * * * * /tmp/log/ShellCrash/task/task.sh 106 运行时每10分钟自动保存面板配置' >>/etc/crontabs/root

fi

if [ ! -d /tmp/log/ShellCrash/jsons ];then
mkdir /tmp/log/ShellCrash/jsons -p
fi

if [ ! -f /tmp/log/ShellCrash/config.yaml ];then
sh /tmp/log/ShellCrash/start.sh get_core_config >/tmp/clashSubupdate.log
fi

while true
do


if killall -q -0 CrashCore ;then
break
else
sh /tmp/log/ShellCrash/menu.sh -s start >/dev/null &
sleep 5
fi
	
done

rm /tmp/ikipk/socks5/data/config/status -rf
		



tunip=`iptables -vnL OUTPUT --line-number|grep "198.18.0"|wc -l`
if [ $tunip -gt 0 ];then
iptables -D INPUT -d 198.18.0.0/30 -j DROP  >/dev/null 2>&1
iptables -D OUTPUT -d 198.18.0.0/30 -j DROP >/dev/null 2>&1
iptables -D INPUT -d 198.18.0.0/30 -j DROP >/dev/null 2>&1
iptables -D OUTPUT -d 198.18.0.0/30 -j DROP >/dev/null 2>&1
fi

}

Clash_start(){

plugin_link=`readlink $BASH_SOURCE`
plugin_dir=`dirname $plugin_link`
plugin_dir=$plugin_dir
export OLDPWD='/tmp/log/ShellCrash'
export CRASHDIR='/tmp/log/ShellCrash'
dns_config=0
if killall -q -0 CrashCore ;then
	local status=1
	if [ $dns_config -eq 1 ];then
		sh /tmp/log/ShellCrash/menu.sh -s start >/dev/null &
	fi

else

export OLDPWD='/tmp/log/ShellCrash'
export CRASHDIR='/tmp/log/ShellCrash'
clash_update_url=`cat /etc/crontabs/root|grep "面板"|wc -l`
if [ $clash_update_url -eq 0 ];then

#echo '0 8 * * * /tmp/log/ShellCrash/task/task.sh 104 在每日的8点0分更新订阅并重启服务' >>/etc/crontabs/root

echo '*/10 * * * * /tmp/log/ShellCrash/task/task.sh 106 运行时每10分钟自动保存面板配置' >>/etc/crontabs/root

fi

if [ ! -d /tmp/log/ShellCrash/jsons ];then
mkdir /tmp/log/ShellCrash/jsons -p
fi

if [ ! -f /tmp/log/ShellCrash/config.yaml ];then
sh /tmp/log/ShellCrash/start.sh get_core_config >/tmp/clashSubupdate.log
fi

sh /tmp/log/ShellCrash/menu.sh -s start >/dev/null &

echo '3' >>/tmp/clash.log
tunip=`iptables -vnL OUTPUT --line-number|grep "198.18.0"|wc -l`
if [ $tunip -gt 0 ];then
iptables -D INPUT -d 198.18.0.0/30 -j DROP  >/dev/null 2>&1
iptables -D OUTPUT -d 198.18.0.0/30 -j DROP >/dev/null 2>&1
iptables -D INPUT -d 198.18.0.0/30 -j DROP >/dev/null 2>&1
iptables -D OUTPUT -d 198.18.0.0/30 -j DROP >/dev/null 2>&1
fi

fi

}

stop(){
sh /tmp/log/ShellCrash/menu.sh -s stop >/dev/null &

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

dns_no=`cat /tmp/log/ShellCrash/configs/ShellCrash.cfg |grep "dns_no"|grep "已禁用"|wc -l`
. /tmp/log/ShellCrash/configs/ShellCrash.cfg
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


clear_link(){

sed -i '/Url=/d' /tmp/log/ShellCrash/configs/ShellCrash.cfg
rm /tmp/log/ShellCrash/yamls/config.yaml -rf
rm /tmp/ShellCrash/* -rf


if [ -d /tmp/ikipk/socks5 ];then

	if [ -f /tmp/log/ShellCrash/yamls/proxies.yaml ];then

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


				sed 's/^/  /' "/tmp/log/ShellCrash/yamls/proxies.yaml" > /tmp/proxies_indented
				sed -i "/^proxies:/r /tmp/proxies_indented" /tmp/ShellCrash/config.yaml
				cat /tmp/log/ShellCrash/yamls/rules.yaml >>/tmp/ShellCrash/config.yaml
				curl -X PUT "http://127.0.0.1:9999/configs" -d '{"path": "/tmp/ShellCrash/config.yaml"}'
		fi

	fi
	
fi
}

update_config_value() {

echo "key=${key}"
echo "new_value=${new_value}"

if [ -z "$key" ] || [ -z "$new_value" ]; then
	echo "Key or value is missing"
	return 1
fi

sed -i '/Url=/d' /tmp/log/ShellCrash/configs/ShellCrash.cfg
echo "Url='${new_value}'" >> /tmp/log/ShellCrash/configs/ShellCrash.cfg

sh /tmp/log/ShellCrash/start.sh get_core_config >/tmp/clashSubupdate.log &
sleep 5
sh /tmp/log/ShellCrash/menu.sh -s start >/dev/null &

}


conrtl() {
if killall -q -0 ttyd ;then
	local ttydstatus=1
else
	local ttydstatus=0
fi
ttyd -c admin:ttyd -p 2222 -i 0.0.0.0  $plugin_dir/conrtl >/dev/null &

}

__show_dconfig(){

    cp /tmp/log/ShellCrash/yamls/config.yaml /tmp/iktmp/export/config.yaml
	configfile=config.yaml
	json_append __json_result__ configfile:str
	
}

config(){

file_type=`echo $Filename|awk -F "." '{print $NF}'`
echo $file_type >/tmp/classh.log
 if [ -f /tmp/iktmp/import/file ]; then

	if [ "$file_type" == "jsons" ];then
		mv /tmp/iktmp/import/file /tmp/log/ShellCrash/jsons/$Filename
	else
		mv /tmp/iktmp/import/file /tmp/log/ShellCrash/yamls/$Filename
	fi

 fi
	
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

