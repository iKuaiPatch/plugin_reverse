#!/bin/bash /etc/ikcommon 

start(){




if [ -f /etc/mnt/vnt-cli ];then

	if [ -f /sbin/data/vnt-cli ];then
		
		if [ ! -f /usr/bin/vnt ];then
			ln -s /sbin/data/vnt-cli /usr/bin/vnt
		fi
	
		if [ ! -f /usr/ikuai/www/vnt-cli ];then
			ln -s /etc/mnt/vnt-cli /usr/ikuai/www/vnt-cli.txt
		fi
		rm /tmp/vnt-cli -rf
		while true
		do
				if ping -W 5 -c1 qq.com >/tmp/null;then
					break
					else
					sleep 3

				fi
		done
		vnt -f /etc/mnt/vnt-cli  >>/tmp/vnt-cli &
		killall vnl
	fi

iptables -t nat -A POSTROUTING -o vnt-tun -s 0.0.0.0/0 -j MASQUERADE

else

echo "不存在配置文件VNT" >> /tmp/vnt22.log
fi

}




VNT_start(){

if killall -q -0 vnt;then
	killall vnt
	return
fi


if [ -f /etc/mnt/vnt-cli ];then

	if [ -f /sbin/data/vnt-cli ];then
		
		if [ ! -f /usr/bin/vnt ];then
			ln -s /sbin/data/vnt-cli /usr/bin/vnt
		fi
	
		if [ ! -f /usr/ikuai/www/vnt-cli ];then
			ln -s /etc/mnt/vnt-cli /usr/ikuai/www/vnt-cli.txt
		fi
		rm /tmp/vnt-cli -rf
		echo "启动配置文件VNT" >> /tmp/vnt22.log
		vnt -f /etc/mnt/vnt-cli  >>/tmp/vnt-cli &
		killall vnl
	fi

iptables -t nat -I POSTROUTING -o vnt-tun -s 0.0.0.0/0 -j MASQUERADE

else

echo "不存在配置文件VNT" >> /tmp/vnt22.log
fi
iptables -t nat -A POSTROUTING -o tailscale0 -s 0.0.0.0/0 -j MASQUERADE
#tailscale0

}

stop(){
killall vnt
rm /etc/mnt/vnt-cli

iptables -t nat -D POSTROUTING -o vnt-tun -s 0.0.0.0/0 -j MASQUERADE
}

config(){

 if [ -f /tmp/iktmp/import/file ]; then
   filesize=$(stat -c%s "/tmp/iktmp/import/file")
   if [ $filesize -lt 524288 ]; then
	mv /tmp/iktmp/import/file /etc/mnt/vnt-cli
	VNT_start
   fi
   
 fi

}

update_config(){


#echo "All Parameters: $@" >> /tmp/socat.log

# 提取每个参数的值
for param in "$@"
do
    case $param in
        server=*)
            server="${param#*=}"
            ;;
        token=*)
            token="${param#*=}"
            ;;
        password=*)
            password="${param#*=}"
            ;;
        dev_name=*)
            dev_name="${param#*=}"
            ;;
		Virtual_ip=*)
            Virtual_ip="${param#*=}"
            ;;
    esac
done



echo "token: ${token}" >/etc/mnt/vnt-cli

if [ ! -z $dev_name ]|| [ $dev_name != " " ];then
	echo "name: ${dev_name}" >>/etc/mnt/vnt-cli
	id=`echo ${dev_name}|md5sum |awk -F " " '{print $1}'`
	echo "device_id: ${id}" >>/etc/mnt/vnt-cli
fi

if [ ! -z $server ];then
	echo "server_address: ${server}" >>/etc/mnt/vnt-cli
fi

if [ ! -z $password ];then

	echo "password: ${password}" >>/etc/mnt/vnt-cli
	echo "server_encrypt: true" >>/etc/mnt/vnt-cli

fi

if [ ! -z $Virtual_ip ];then
	echo "ip: ${Virtual_ip}" >>/etc/mnt/vnt-cli
fi



echo "stun_server:" >>/etc/mnt/vnt-cli
echo "  - stun.miwifi.com" >>/etc/mnt/vnt-cli
echo "  - stun.chat.bilibili.com" >>/etc/mnt/vnt-cli
echo "parallel: 1" >>/etc/mnt/vnt-cli
echo "cipher_model: aes_gcm" >>/etc/mnt/vnt-cli
echo "dns:" >>/etc/mnt/vnt-cli
echo "  - 223.5.5.5" >>/etc/mnt/vnt-cli
echo "  - 8.8.8.8" >>/etc/mnt/vnt-cli
echo "out_ips:" >>/etc/mnt/vnt-cli
echo "  - 0.0.0.0/0" >>/etc/mnt/vnt-cli
echo "disable_stats: true" >>/etc/mnt/vnt-cli

    if killall -q -0 vnt ; then
        killall vnt
    fi
    VNT_start
}


show(){
    Show __json_result__
}

__show_status(){
local status=0

if killall -q -0 vnt ;then
	local status=1
	info=`cat /tmp/vnt-cli`
Name=$(cat /etc/mnt/vnt-cli |grep name|awk -F " " '{print $2}')
#Virtual_ip=$(echo "$info" | sed -n 's/.*Virtual ip: \([^\ ]*\).*/\1/p')

Virtual_ip=$(ip addr show vnt-tun | grep 'inet ' | awk '{ print $2 }' | cut -d/ -f1)


Virtual_gateway=$(cat /tmp/vnt-cli |grep "gateway"|awk -F "=" '{print $4}')
Virtual_netmask=$(cat /tmp/vnt-cli |grep "netmask"|awk -F "=" '{print $3}'|awk -F " " '{print $1}')
Connection_status=$(echo "$info" | sed -n 's/.*Connection status: \([^\ ]*\).*/\1/p')
NAT_type=$(echo "$info" | sed -n 's/.*NAT type: \([^\ ]*\).*/\1/p')
Relay_server=$(cat vnt-cli |grep "address"|awk -F "=" '{print $3}')
Public_ips=$(echo "$info" | sed -n 's/.*Public ips: \([^\ ]*\).*/\1/p')
Local_addr=$(echo "$info" | sed -n 's/.*Local addr: \([^\ ]*\).*/\1/p')
IPv6=$(echo "$info" | sed -n 's/.*IPv6: \([^\ ]*\).*/\1/p')

	
else
	local status=0
fi


token=`cat /etc/mnt/vnt-cli |grep "token"|awk -F " " '{print $2}'`
json_append __json_result__ status:int
json_append __json_result__ Name:str
json_append __json_result__ Virtual_ip:str
json_append __json_result__ Virtual_gateway:str
json_append __json_result__ Virtual_netmask:str
json_append __json_result__ Connection_status:str
json_append __json_result__ NAT_type:str
json_append __json_result__ Relay_server:str
json_append __json_result__ Public_ips:str
json_append __json_result__ Local_addr:str
json_append __json_result__ IPv6:str
json_append __json_result__ token:str






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
