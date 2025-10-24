#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")
if [ ! -d /tmp/AdGuardHome ];then
mkdir /tmp/AdGuardHome
fi

if [ ! -f /sbin/AdGuardHome ];then
	if [ -f $plugin_dir/../data/AdGuardHome ];then
		chmod +x $plugin_dir/../data/AdGuardHome
		ln -fs $plugin_dir/../data/AdGuardHome /sbin/AdGuardHome
	fi
fi

if [ ! -d /etc/mnt/ikuai/app_config ];then
mkdir -p /etc/mnt/ikuai/app_config
fi




networks(){

while true
do
if ping -W 5 -c1 qq.com >/tmp/null;then
		
break
fi
sleep 3
done

}



dns_start(){


echo "1" >/etc/mnt/AdGuard.conf
dns5353=`iptables -t nat -vnL PREROUTING --line-number|grep "5353"|wc -l`
if [ $dns5353 -eq 0 ];then
iptables -t nat -I PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 5353
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
ip6tables -t nat -I PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 5353
ip6tables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
fi

}

dns_stop(){
	echo "0" >/etc/mnt/AdGuard.conf
	while true
	do
		dns5353=`iptables -t nat -vnL PREROUTING --line-number|grep "5353"|wc -l`
		if [ $dns5353 -gt 0 ];then
			iptables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 5353
			iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
			ip6tables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 5353
			ip6tables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
		else
			break
		fi
	
	done
}

dns_set(){
echo "$dnsconf" >/tmp/AdGuards.log
if [ $dnsconf -eq 1 ];then
dns_start
else
dns_stop
fi

}






start(){


if [ ! -f /etc/mnt/ikuai/app_config/AdGuardHome ];then
	return
fi


if killall -q -0 AdGuardHome;then
	return
fi
echo "1" >/tmp/AdGuard.log
if [  -f /etc/mnt/AdGuardHome/AdGuardHome.yaml ];then
	mkdir /tmp/AdGuardHome/data -p
	mkdir /etc/mnt/AdGuardHome/filters -p
	rm /etc/mnt/AdGuardHome/data -rf
	ln -s /tmp/AdGuardHome/data /etc/mnt/AdGuardHome/data
	#ln -s /etc/mnt/AdGuardHome/filters /etc/mnt/AdGuardHome/data/filters
	/sbin/AdGuardHome -w /etc/mnt/AdGuardHome  >/dev/null &
fi

if [ ! -f /etc/mnt/AdGuardHome/AdGuardHome.yaml ];then
	mkdir /etc/mnt/AdGuardHome -p
	mkdir /tmp/AdGuardHome/data -p
	mkdir /etc/mnt/AdGuardHome/filters -p
	rm /etc/mnt/AdGuardHome/data -rf
	ln -s /tmp/AdGuardHome/data /etc/mnt/AdGuardHome/data
	#ln -s /etc/mnt/AdGuardHome/filters /etc/mnt/AdGuardHome/data/filters
	/sbin/AdGuardHome -w /etc/mnt/AdGuardHome  >/dev/null &
fi
  
dnsconf=`cat /etc/mnt/AdGuard.conf`
if [ $dnsconf -eq 1 ];then
	dns_start
else
	dns_stop
fi
  
}


AD_start(){

if killall -q -0 AdGuardHome;then
	killall AdGuardHome
	dns_stop
	echo "停止AdGuardHome成功" >>/tmp/AdGuard.log
	rm /etc/mnt/ikuai/app_config/AdGuardHome
	return
fi


echo "1" >/etc/mnt/ikuai/app_config/AdGuardHome
start

}

show()
{
    Show __json_result__
}


__show_status()
{
if killall -q -0 AdGuardHome ;then

	local status=1
	
else

	local status=0
fi

if [ ! -d /tmp/AdGuardHome ];then
	local status=2
fi
local dnsconf=`cat /etc/mnt/AdGuard.conf`

	json_append __json_result__ dnsconf:int
	json_append __json_result__ status:int
	
}



AD_disable(){
	AD_stop
	rm /etc/mnt/AdGuardHome.yaml -rf
	rm /etc/mnt/AdGuardHome -rf
	rm /tmp/AdGuardHome/AdGuardHome.yaml -f
	rm /tmp/AdGuardHome/data -r -f
	rm /tmp/AdGuardHome -r -f
	echo "禁用AdGuardHome成功" >>/tmp/AdGuard.log
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
