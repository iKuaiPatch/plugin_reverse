#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


md5sum $plugin_dir/../data/smartdns | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit

echo $plugin_dir >/tmp/smardnsye.log
if [ ! -d /etc/mnt/ikuai/app_config ];then
mkdir -p /etc/mnt/ikuai/app_config
fi

if [ ! -f  /etc/smartdns/smartdns.conf ];then
ln -s $plugin_dir/../data/config /etc/smartdns
fi

if [ ! -f /usr/sbin/smartdns ];then
chmod +x $plugin_dir/../data/smartdns
ln -s $plugin_dir/../data/smartdns /usr/sbin/smartdns

fi



if [ ! -f /etc/smartdns/address.conf ];then
echo '' >/etc/smartdns/address.conf
fi

if [ ! -f /etc/smartdns/blacklist-ip.conf ];then
echo '' >/etc/smartdns/blacklist-ip.conf
fi

if [ ! -f /etc/smartdns/custom.conf ];then
echo '' >/etc/smartdns/custom.conf
fi


start(){

if [ -f /etc/mnt/ikuai/app_config/smartdns ];then
rm /etc/smartdns/*.log
smartdns  >/dev/null &


fi

}





app_start(){

if killall -q -0 smartdns;then
	killall smartdns
	return
fi


echo "1" >/etc/mnt/ikuai/app_config/smartdns

start

}



stop(){
killall smartdns
rm /etc/mnt/ikuai/app_config/smartdns
}



config(){
echo "1" >>/tmp/npsconfig.log
 if [ -f /tmp/iktmp/import/file ]; then
   filesize=$(stat -c%s "/tmp/iktmp/import/file")
   if [ $filesize -lt 524288 ]; then
			rm $plugin_dir/../data/config/smartdns.conf
			mv /tmp/iktmp/import/file $plugin_dir/../data/config/smartdns.conf
			echo "ok" >>/tmp/npsconfig.log
			killall smartdns
			start1
   fi
   
 fi

}

#echo "All Parameters: $@" >> /tmp/smartdnszzz.log

update_server(){

echo "All Parameters: $@" >> /tmp/smartdnszzz.log

if [ $ipBlacklist == "false" ];then

ipBlacklist=''

fi 

#echo ${dnsIp},${protocol},${dnsPort},${group},${ipBlacklist},${extraParams} >>/tmp/smartdnstest.config
if [ -z "$dnsPort" ];then
echo ${protocol} ${dnsIp} ${group} ${ipBlacklist} ${extraParams} >>$plugin_dir/../data/config/smartdns.conf
else
echo ${protocol} ${dnsIp}:${dnsPort} ${group} ${ipBlacklist} ${extraParams} >>$plugin_dir/../data/config/smartdns.conf
fi 

}


delete_server(){

	#echo "All Parameters: $@" >> /tmp/smartdnszzz2.log
    #rowIndex=${rowIndex} 
	
	line_numbers=$(grep -n "$dnsIp" /etc/smartdns/smartdns.conf | cut -d: -f1)
	
	for line in $line_numbers; do
	  sed -i "${line}d" /etc/smartdns/smartdns.conf
	done


    #sed -i "${rowIndex}d" /tmp/smartdnstest.config  # 删除指定行
    

}


__show_getconfig(){
   id=1
	cat /etc/smartdns/smartdns.conf|grep "server"|grep -v "server-name"|grep -v "#" |grep "^server" >/tmp/smardns.tmp.log
	cat /etc/smartdns/smartdns.conf|grep "server"|grep -v "server-name"|grep -v "#" |grep "^nameserver" >>/tmp/smardns.tmp.log
    while IFS= read -r line
    do
		dnsIp='' && protocol='' && dnsPort='' && group='' && ipBlacklist='' && extraParams=''
		echo "$line" >> /tmp/smardnslll.tmp.log
            dnsIp=$(echo "$line" | awk -F " " '{print $2}')
			
			if  [[ "$dnsIp" == *:* ]] && [[ "$dnsIp" != *https:* ]]&& [[ "$dnsIp" != *tls:* ]];then
				dnsPort=$(echo "$dnsIp" | awk -F ":" '{print $2}')
			else
				dnsPort="默认"
			fi

			protocol=$(echo "$line" | awk -F " " '{print $1}')
			if [ $protocol == "server" ];then
				protocol=UDP
			fi
			if [ $protocol == "server-https" ];then
				protocol=HTTPS
			fi
			if [ $protocol == "nameserver" ];then
				protocol=DOH
			fi
			if [ $protocol == "server-tcp" ];then
				protocol=TCP
			fi
			if [ $protocol == "server-tls" ];then
				protocol=TLS
			fi

			
			
			if [[ "$line" == *-group* ]]; then
				group=$(echo "$line" | awk -F " " '{print $4}')
				echo "$dnsIp" "$group" >> /tmp/smardnslll.tmp.log
			fi
			
			if [ -z "$group" ];then
				group="默认"
			fi
			
			if  [[ "$line" == *-blacklist-ip* ]];then
				ipBlacklist=true
			else
				ipBlacklist=false
			fi
			
			if  [[ "$line" == *-blacklist-ip* ]] && [[ "$line" == *-group* ]];then
				extraParams=$(echo "$line" | awk -F " " '{print $6}')
			fi
			
			if  [[ "$line" == *-blacklist-ip* ]] && [[ "$line" != *-group* ]];then
				extraParams=$(echo "$line" | awk -F " " '{print $4}')
			fi
			
			if  [[ "$line" != *-blacklist-ip* ]] && [[ "$line" == *-group* ]];then
				extraParams=$(echo "$line" | awk -F " " '{print $5}')
			fi
			
			if  [[ "$line" != *-blacklist-ip* ]] && [[ "$line" != *-group* ]];then
				extraParams=$(echo "$line" | awk -F " " '{print $3}')
			fi
			
			local id$id=$(json_output id:int dnsIp:str protocol:str dnsPort:str group:str ipBlacklist:bool extraParams:str)
			json_append __json_result__ id$id:json
        id=$((id + 1))
    done < /tmp/smardns.tmp.log 
	

}



update_config(){

echo "All Parameters: $@" > /tmp/smartdnsaaa.log
echo "$plugin_dir/../data/config/smartdns.conf" >>/tmp/smartdnsaaa.log

cat /etc/smartdns/smartdns.conf|grep "server"|grep -v "server-name"|grep -v "#" |grep "^server" >/tmp/smardns.tmp.log
cat /etc/smartdns/smartdns.conf|grep "server"|grep -v "server-name"|grep -v "#" |grep "^nameserverr" >>/tmp/smardns.tmp.log
	

echo server-name ${serverName} >$plugin_dir/../data/config/smartdns.conf       			   # 服务器名称





echo "bind :${localPort}" >>$plugin_dir/../data/config/smartdns.conf						      # IPV6 服务器
if [ ${tcpServer} == "true" ] ;then
	 echo "bind-tcp :${localPort}" >>$plugin_dir/../data/config/smartdns.conf
fi


if [ ${dualStackIP} == "false" ];then
echo '#关闭双栈 IP 优选' >>$plugin_dir/../data/config/smartdns.conf   
	echo 'dualstack-ip-selection no' >>$plugin_dir/../data/config/smartdns.conf                         # 双栈 IP 优选
fi

if [ ${domainPreload} == "true" ];then
echo '# 开启域名预加载' >>$plugin_dir/../data/config/smartdns.conf  
	echo 'prefetch-domain yes' >>$plugin_dir/../data/config/smartdns.conf  						       # 域名预加载
fi
				
if [ ${cacheExpire} == "true" ];then		 
     echo 'serve-expired yes' >>$plugin_dir/../data/config/smartdns.conf						           # 缓存过期服务
fi
				
if [ ! -z $cacheExpire ];then
	echo "cache-size ${cacheSize}" >>$plugin_dir/../data/config/smartdns.conf						    # 缓存大小
fi
	
       
#if [ ${resolveLocalHost} == "true" ];then
#	echo 'dnsmasq-lease-file /tmp/dhcp.leases' >>$plugin_dir/../data/config/smartdns.conf 				# 解析本地主机名
#fi

if [ $disableIpv6 == "true" ] && [ $disableHttps == "true" ];then
	echo 'force-qtype-SOA  28 65' >>$plugin_dir/../data/config/smartdns.conf
	
	else
	
	if [ ${disableIpv6} == "true" ];then
		echo 'force-qtype-SOA  28' >>$plugin_dir/../data/config/smartdns.conf						        # 停用 IPV6 地址解析   未找到
	fi

	if [ ${disableHttps} == "true" ];then
		 echo 'force-qtype-SOA  65' >>$plugin_dir/../data/config/smartdns.conf    							   # 停用 HTTPS 地址解析  未找到
	fi
	
fi



if [ ${autoDnsmasq} == "true" ];then
                #autoDnsmasq: false       # 自动设置 Dnsmasq     未找到

if [ -f $plugin_dir/../data/config/autoDnsmasq.conf ];then


	ysport=`cat $plugin_dir/../data/config/autoDnsmasq.conf` 
	if [ "$ysport" != "${localPort}" ];then
		iptables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports ${ysport} >/dev/null 2>$1
		iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports ${ysport} >/dev/null 2>$1
		ip6tables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports ${ysport} >/dev/null 2>$1
		ip6tables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports ${ysport} >/dev/null 2>$1
	fi


fi
	echo "${localPort}" >>$plugin_dir/../data/config/autoDnsmasq.conf 

# 解析本地主机名
resolve=`iptables -t nat -vnL PREROUTING --line-number|grep "${localPort}"|wc -l`
	if [ $resolve -eq 0 ];then
		iptables -t nat -I PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports ${localPort}
		iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports ${localPort}
		ip6tables -t nat -I PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports ${localPort}
		ip6tables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports ${localPort}
	fi 
else
	if [ -f $plugin_dir/../data/config/autoDnsmasq.conf ];then
		ysport=`cat $plugin_dir/../data/config/autoDnsmasq.conf` 
			iptables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports ${ysport} >/dev/null 2>$1
			iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports ${ysport} >/dev/null 2>$1
			ip6tables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports ${ysport} >/dev/null 2>$1
			ip6tables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports ${ysport} >/dev/null 2>$1
			rm $plugin_dir/../data/config/autoDnsmasq.conf
	fi			
fi

				
if [ ! -z $domainTTL ];then
	echo "rr-ttl ${domainTTL}" >>$plugin_dir/../data/config/smartdns.conf                         # 域名 TTL
fi	

if [ ! -z $domainTTLMin ];then
echo "rr-ttl-min ${domainTTLMin}" >>$plugin_dir/../data/config/smartdns.conf         		  # 域名 TTL 最小值
fi

if [ ! -z $domainTTLMax ];then
	echo "rr-ttl-max ${domainTTLMax}" >>$plugin_dir/../data/config/smartdns.conf     		      # 域名 TTL 最大值
fi
if [ ! -z $responseTTLMax ];then
	echo "rr-ttl-reply-max ${responseTTLMax}" >>$plugin_dir/../data/config/smartdns.conf           # 回应的域名 TTL 最大值
fi

echo '#设置日志文件' >>$plugin_dir/../data/config/smartdns.conf
echo 'log-level error' >>$plugin_dir/../data/config/smartdns.conf
echo 'log-size 64k' >>$plugin_dir/../data/config/smartdns.conf
echo 'log-num 0' >>$plugin_dir/../data/config/smartdns.conf

echo '#引入中国域名列表' >>$plugin_dir/../data/config/smartdns.conf
echo 'conf-file /etc/smartdns/cn.conf' >>$plugin_dir/../data/config/smartdns.conf

cat /tmp/smardns.tmp.log >>$plugin_dir/../data/config/smartdns.conf

echo '#自定义配置' >>$plugin_dir/../data/config/smartdns.conf
echo 'conf-file /etc/smartdns/address.conf' >>$plugin_dir/../data/config/smartdns.conf
echo 'conf-file /etc/smartdns/blacklist-ip.conf' >>$plugin_dir/../data/config/smartdns.conf
echo 'conf-file /etc/smartdns/custom.conf' >>$plugin_dir/../data/config/smartdns.conf





if [ "$skipTest" == "true" ];then
skipTest='-no-speed-check'
else
skipTest=''
fi
if [ "$skipAddressRule" == "true" ];then
skipAddressRule='-no-rule-addr'
else
skipAddressRule=''
fi
if [ "$skipNameserverRule" == "true" ];then
skipNameserverRule='-no-rule-nameserver'
else
skipNameserverRule=''
fi
if [ "$skipIPsetRule" == "true" ];then
skipIPsetRule='-no-rule-ipset'
else
skipIPsetRule=''
fi
if [ "$skipAddressSOARule" == "true" ];then
skipAddressSOARule='-no-rule-soa'
else
skipAddressSOARule=''
fi
if [ "$skipDualStack" == "true" ];then
skipDualStack='-no-dualstack-selection'
else
skipDualStack=''
fi
if [ "$skipCache" == "true" ];then
skipCache='-no-cache'
else
skipCache=''
fi
if [ "$disableIPv62" == "true" ];then
disableIPv62='-force-aaaa-soa'
else
disableIPv62=''

fi

if [ ! -z "$serverGroup" ];then
serverGroup1='-group '$serverGroup
serverGroup=$serverGroup1
else
serverGroup=''
fi




if [ "$enable" == "true" ];then




	if [ ${ipv6Server} == "true" ];then
			
			
		 if [ "$tcpServer2" == "true" ];then
			echo "bind [::]:${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62"  >>$plugin_dir/../data/config/smartdns.conf
			echo "bind-tcp [::]:${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62"  >>$plugin_dir/../data/config/smartdns.conf
		else
			echo "bind [::]:${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62"  >>$plugin_dir/../data/config/smartdns.conf
		fi
		
		
	else
				
		if [ "$tcpServer2" == "true" ];then
				echo "bind :${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62"  >>$plugin_dir/../data/config/smartdns.conf
				echo "bind-tcp :${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62"  >>$plugin_dir/../data/config/smartdns.conf
				
		else
				echo "bind :${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62"  >>$plugin_dir/../data/config/smartdns.conf
				
		fi
	fi
	
	
	
	
	
fi







}



show(){
	
    Show __json_result__
}

__show_status(){
local status=0

if killall -q -0 smartdns ;then
local status=1
fi
	json_append __json_result__ status:int
	
	
	serverName=`cat /etc/smartdns/smartdns.conf | grep "^server-name" | awk '{print $2}'`

	domainTTL=`cat /etc/smartdns/smartdns.conf | grep "^rr-ttl " | awk '{print $2}'`
	
	domainTTLMin=`cat /etc/smartdns/smartdns.conf | grep "^rr-ttl-min " | awk '{print $2}'`
	domainTTLMax=`cat /etc/smartdns/smartdns.conf | grep "^rr-ttl-max " | awk '{print $2}'`
	responseTTLMax=`cat /etc/smartdns/smartdns.conf | grep "^rr-ttl-reply-max " | awk '{print $2}'`
	
	
	ipv6Server=`cat /etc/smartdns/smartdns.conf |grep "\[::\]"|wc -l`
	if [ $ipv6Server -ne 0 ];then
	ipv6Server=true
	else
	ipv6Server=false
	fi


	dualStackIP=`cat /etc/smartdns/smartdns.conf | grep "^dualstack-ip-selection"|wc -l`
	if [ $dualStackIP -eq 0 ];then
	dualStackIP=true
	else
	dualStackIP=false
	fi
	
	
	
		bind_lines1=$(grep "^bind-tcp " /etc/smartdns/smartdns.conf)
		bind_lines_bind_tcp=$(echo "$bind_lines1" | wc -l)
		if [ "$bind_lines_bind_tcp" -ge 1 ]; then
			firstTab_tcpServer=true
			tcpServer=true
		else
			tcpServer=true
			firstTab_tcpServer=false
		fi


	tcpServer=`cat /etc/smartdns/smartdns.conf | grep "^bind-tcp "|wc -l`
	if [ $tcpServer -ne 0 ];then
	tcpServer=true
	else
	tcpServer=false
	fi



	domainPreload=`cat /etc/smartdns/smartdns.conf | grep "^prefetch-domain "|wc -l`
	if [ $domainPreload -ne 0 ];then
	domainPreload=true
	else
	domainPreload=false
	fi

	
	
	cacheExpire=`cat /etc/smartdns/smartdns.conf | grep "^serve-expired "|wc -l`
	if [ $cacheExpire -ne 0 ];then
	cacheExpire=true
	else
	cacheExpire=false
	fi
	
	
	
	resolveLocalHost=`cat /etc/smartdns/smartdns.conf | grep "^dnsmasq-lease-file "|wc -l`
	if [ $resolveLocalHost -ne 0 ];then
	resolveLocalHost=true
	else
	resolveLocalHost=false
	fi
	
	disableIpv6_status=`cat /etc/smartdns/smartdns.conf | grep "^force-qtype-SOA"|wc -l`
	if [ $disableIpv6_status -ne 0 ];then

		disableHttps1=`cat /etc/smartdns/smartdns.conf | grep "^force-qtype-SOA"|grep "65"|wc -l`
			if [ $disableHttps1 -ne 0 ];then
				disableHttps=true
			else
				disableHttps=false
			
			fi
	
		disableIpv61=`cat /etc/smartdns/smartdns.conf | grep "^force-qtype-SOA"|grep "28"|wc -l`
			if [ $disableIpv61 -ne 0 ];then
				disableIpv6=true
			else
				disableIpv6=false
			fi
	else
		disableHttps=false
		disableIpv6=false		
			
	fi

	
bind_lines=$(grep "^bind " /etc/smartdns/smartdns.conf)

line_count=$(echo "$bind_lines" | wc -l)

if [ "$line_count" -ge 1 ]; then

	  localPort=$(echo "$bind_lines" | head -n 1 | awk -F ':' '{print $NF}' | xargs)


  if [ "$line_count" -gt 1 ]; then
	   localPort2=$(echo "$bind_lines" | head -n 2 | tail -n 1 | awk -F ':' '{print $NF}' | awk '{print $1}' | xargs)
	   	if [ ! -z "localPort2" ];then
		server_tcp_num=`grep ":${localPort2}" /etc/smartdns/smartdns.conf |wc -l`
			if [ $server_tcp_num -eq 2 ];then
			 tcpServer2=true
			 else
			 tcpServer2=false
			fi
		server2-tcp=`grep ":5353" /etc/smartdns/smartdns.conf |wc -l`
		fi
		
	   enable=true
	   
	   skipIPsetRule=`echo "$bind_lines"|grep 'no-speed-check'|wc -l`
	   if [ $skipIPsetRule -ne 0 ];then
		skipIPsetRule=true
	   else
		skipIPsetRule=false
	   fi
	   
	   serverGroup=`echo "$bind_lines"|grep "group"|wc -l`
	   if [ $serverGroup -ne 0 ];then
		serverGroup=$(echo "$bind_lines" | awk -F "-group" '{print $2}' | awk -F " " '{print $1}' | xargs)
	   fi
	   
	   skipTest=`echo "$bind_lines"|grep 'no-speed-check'|wc -l`
	   if [ $skipTest -ne 0 ];then
	   skipTest=true
	   else
	   skipTest=false
	   fi
	  
	  skipAddressRule=`echo "$bind_lines"|grep "no-rule-addr"|wc -l`
	   if [ $skipAddressRule -ne 0 ];then
	   skipAddressRule=true
	   else
	   skipAddressRule=false
	   fi
	   
	   skipNameserverRule=`echo "$bind_lines"|grep "no-rule-nameserver"|wc -l`
	   if [ $skipNameserverRule -ne 0 ];then
	   skipNameserverRule=true
	   else
	   skipNameserverRule=false
	   fi
	   
	   
	   skipIPsetRule=`echo "$bind_lines"|grep "no-rule-ipset"|wc -l`
	   if [ $skipIPsetRule -ne 0 ];then
		skipIPsetRule=true
	   else
		skipIPsetRule=false
	   fi
	   
	   skipAddressSOARule=`echo "$bind_lines"|grep "no-rule-soa"|wc -l`
	   if [ $skipAddressSOARule -ne 0 ];then
		skipAddressSOARule=true
	   else
		skipAddressSOARule=false
	   fi
	   
	   
	   skipDualStack=`echo "$bind_lines"|grep "no-dualstack-selection"|wc -l`
	   if [ $skipDualStack -ne 0 ];then
		skipDualStack=true
	   else
		skipDualStack=false
	   fi
	   
	   skipCache=`echo "$bind_lines"|grep "no-cache"|wc -l`
	   if [ $skipCache -ne 0 ];then
		skipCache=true
	   else
		skipCache=false
	   fi
	   ipv6Server2=`echo "$bind_lines"|grep "force-aaaa-soa"|wc -l`
	   if [ $ipv6Server2 -ne 0 ];then
		ipv6Server2=true
	   else
		ipv6Server2=false
	   fi
  fi
  
  else
  localPort=`cat /etc/smartdns/smartdns.conf | grep "^bind " | awk -F ":" '{print $NF}'`
  enable=false
  
fi

	cacheSize=`cat /etc/smartdns/smartdns.conf | grep "^cache-size" | awk '{print $2}'`
	

	
	
# 目标文件路径
FILE_PATH="/etc/smartdns/smartdns.conf"

# 检查文件是否存在
if [  -f "$FILE_PATH" ]; then
encoded_content=$(base64 "$FILE_PATH" | tr -d '\n')
fi


if [ -f $plugin_dir/../data/config/autoDnsmasq.conf ];then
autoDnsmasq=true
else
autoDnsmasq=false
fi
	
	

	json_append __json_result__ cacheSize:str
	json_append __json_result__ ipv6Server:str
	json_append __json_result__ dualStackIP:str
	json_append __json_result__ tcpServer:str
	json_append __json_result__ serverName:str
    json_append __json_result__ localPort:str
	json_append __json_result__ domainPreload:str
	json_append __json_result__ cacheExpire:str
	json_append __json_result__ resolveLocalHost:str
	json_append __json_result__ autoDnsmasq:str
	json_append __json_result__ disableIpv6:str
	json_append __json_result__ disableHttps:str
	json_append __json_result__ domainTTL:str
	json_append __json_result__ domainTTLMin:str
	json_append __json_result__ domainTTLMax:str
	json_append __json_result__ responseTTLMax:str
	json_append __json_result__ enable:str
	json_append __json_result__ localPort2:str
	json_append __json_result__ skipIPsetRule:str
	json_append __json_result__ serverGroup:str
	json_append __json_result__ skipTest:str
	json_append __json_result__ skipAddressRule:str
	json_append __json_result__ skipNameserverRule:str
	json_append __json_result__ skipAddressSOARule:str
	json_append __json_result__ skipDualStack:str
	json_append __json_result__ skipCache:str
	json_append __json_result__ ipv6Server2:str
	json_append __json_result__ tcpServer2:str
	json_append __json_result__ encoded_content:str
	
	__show_getconfig
}


config(){

 if [ -f /tmp/iktmp/import/file ]; then

	mv /tmp/iktmp/import/file $plugin_dir/../data/config/$Filename

 fi
	
}



saveFileContent(){

#echo "All Parameters: $@" > /tmp/smartdnsaaa.log
echo "$fileContent" | base64 -d > /tmp/smartdnsaaa.log

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
