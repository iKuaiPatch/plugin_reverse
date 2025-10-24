#!/bin/bash /etc/ikcommon 

script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


md5sum $plugin_dir/../data/nps | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit

if [ ! -f /tmp/app/nps/nps ];then
mkdir /tmp/app/nps -p
chmod +x $plugin_dir/../data/nps
ln -fs $plugin_dir/../data/nps /tmp/app/nps/nps

if [ -f /etc/mnt/nps/conf/nps.conf ];then
					ln -s /etc/mnt/nps/conf /tmp/app/nps/conf
					chmod +x /tmp/app/nps/nps
					httpport=`cat /tmp/app/nps/conf/nps.conf|grep "http_proxy_port"|awk -F "=" '{print $2}'`
					httpsport=`cat /tmp/app/nps/conf/nps.conf|grep "https_proxy_port"|awk -F "=" '{print $2}'`
					if [ "$httpport" == "80" ];then
						sed -i "s/http_proxy_port=80/http_proxy_port=880/g"   /tmp/app/nps/conf/nps.conf
					fi
					if [ "$httpsport" == "443" ];then
						sed -i "s/https_proxy_port=443/https_proxy_port=4443/g"   /tmp/app/nps/conf/nps.conf
					fi
					rm /tmp/nps_file.log
		 
else
					mkdir /etc/mnt/nps -p
					cp $plugin_dir/../data/conf /etc/mnt/nps/conf -r
					ln -s /etc/mnt/nps/conf /tmp/app/nps/conf
					chmod +x /tmp/app/nps/nps
					sed -i "s/http_proxy_port=80/http_proxy_port=880/g"   /tmp/app/nps/conf/nps.conf
					sed -i "s/https_proxy_port=443/https_proxy_port=4443/g"   /tmp/app/nps/conf/nps.conf
					rm /tmp/nps_file.log
				

				
fi

ln -s $plugin_dir/../data/web /tmp/app/nps/web

fi



start(){



if [ -f /etc/mnt/nps/conf/nps.conf ];then


	ln -s /etc/mnt/nps/conf/nps.conf /usr/ikuai/www/nps.conf
	sed -i -e '/^\s*#\?\s*auth_key\s*=/s/^\s*#\?\s*auth_key\s*=\s*.*/auth_key=123qazwsx/' /tmp/app/nps/conf/nps.conf
	sed -i -e '/^\s*#\?\s*auth_crypt_key\s*=/s/^\s*#\?\s*auth_crypt_key\s*=\s*.*/auth_crypt_key=qazwsxedcrfv/' /tmp/app/nps/conf/nps.conf
	/tmp/app/nps/nps >/dev/null &


fi

}


NPS_start(){

if killall -q -0 nps;then
	killall nps
	return
fi


	ln -s /etc/mnt/nps/conf/nps.conf /usr/ikuai/www/nps.conf
sed -i -e '/^\s*#\?\s*auth_key\s*=/s/^\s*#\?\s*auth_key\s*=\s*.*/auth_key=123qazwsx/' /tmp/app/nps/conf/nps.conf
sed -i -e '/^\s*#\?\s*auth_crypt_key\s*=/s/^\s*#\?\s*auth_crypt_key\s*=\s*.*/auth_crypt_key=qazwsxedcrfv/' /tmp/app/nps/conf/nps.conf
/tmp/app/nps/nps >/dev/null &



}

stop(){
killall nps
rm /etc/mnt/nps -r
rm /tmp/app/nps/nps
}

config(){
echo "1" >>/tmp/npsconfig.log
 if [ -f /tmp/iktmp/import/file ]; then
   filesize=$(stat -c%s "/tmp/iktmp/import/file")
   echo "$filesize" >>/tmp/npsconfig.log
   if [ $filesize -lt 524288 ]; then
	   if [ -f /etc/mnt/nps/conf/nps.conf ];then
			rm /etc/mnt/nps/conf/nps.conf
			mv /tmp/iktmp/import/file /etc/mnt/nps/conf/nps.conf
			echo "ok" >>/tmp/npsconfig.log
			killall nps
			start
		fi
   fi
   
 fi

}

update_config(){


#echo "All Parameters: $@" >> /tmp/vnts.log

# 提取每个参数的值
for param in "$@"
do
    case $param in
        bridge_port=*)
            bridge_port="${param#*=}"
            ;;
        web_username=*)
            web_username="${param#*=}"
            ;;
        web_password=*)
            web_password="${param#*=}"
            ;;
        web_port=*)
            web_port="${param#*=}"
            ;;
    esac
done


sed -i -e "/^\s*#\?\s*bridge_port\s*=/s/^\s*#\?\s*bridge_port\s*=\s*.*/bridge_port=${bridge_port}/" /tmp/app/nps/conf/nps.conf

sed -i -e "/^\s*#\?\s*web_username\s*=/s/^\s*#\?\s*web_username\s*=\s*.*/web_username=${web_username}/" /tmp/app/nps/conf/nps.conf

sed -i -e "/^\s*#\?\s*web_password\s*=/s/^\s*#\?\s*web_password\s*=\s*.*/web_password=${web_password}/" /tmp/app/nps/conf/nps.conf

sed -i -e "/^\s*#\?\s*web_port\s*=/s/^\s*#\?\s*web_port\s*=\s*.*/web_port=${web_port}/" /tmp/app/nps/conf/nps.conf



    echo "配置文件已更新："
    cat /etc/mnt/npc.config
    if killall -q -0 nps ; then
        killall nps
    fi
    start
}


show(){

    Show __json_result__
}

__show_status(){
local status=0
local npsweb=8080

if [ ! -f /tmp/app/nps/nps ];then
	local status=3
fi

if [ -f /tmp/nps_file.log ];then
local status=2
fi



if killall -q -0 nps ;then
	local status=1


fi

if [ -f /tmp/app/nps/conf/nps.conf ];then
	local npsweb=$(grep '^web_port\s*=' /tmp/app/nps/conf/nps.conf | sed 's/^\s*web_port\s*=\s*\([0-9]\+\)\s*$/\1/')
	   # 提取 web_username 的值
	local web_username=$(grep '^web_username\s*=' /tmp/app/nps/conf/nps.conf | awk -F '=' '{print $2}' | xargs)

	# 提取 web_password 的值
	local web_password=$(grep '^web_password\s*=' /tmp/app/nps/conf/nps.conf | awk -F '=' '{print $2}' | xargs)
	
	local web_port=$(grep '^web_port\s*=' /tmp/app/nps/conf/nps.conf | awk -F '=' '{print $2}' | xargs)
	
	local bridge_port=$(grep '^bridge_port\s*=' /tmp/app/nps/conf/nps.conf | awk -F '=' '{print $2}' | xargs)

fi

	json_append __json_result__ status:int
	json_append __json_result__ npsweb:int
	json_append __json_result__ web_username:str
	json_append __json_result__ web_password:str
	json_append __json_result__ web_port:str
	json_append __json_result__ bridge_port:str
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
