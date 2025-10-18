#!/bin/bash 
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
PLUGIN_NAME="smartdns"
. /etc/mnt/plugins/configs/config.sh

if [ ! -f /etc/smartdns/smartdns.conf ]; then
    ln -s $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config /etc/smartdns
fi

if [ ! -f /usr/sbin/smartdns ]; then
    chmod +x $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/smartdns
    ln -s $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/smartdns /usr/sbin/smartdns

fi

if [ ! -f /etc/smartdns/address.conf ]; then
    echo '' >/etc/smartdns/address.conf
fi

if [ ! -f /etc/smartdns/blacklist-ip.conf ]; then
    echo '' >/etc/smartdns/blacklist-ip.conf
fi

if [ ! -f /etc/smartdns/custom.conf ]; then
    echo '' >/etc/smartdns/custom.conf
fi

start() {

    if [ -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/smartdns ]; then
        rm /etc/smartdns/*.log
        smartdns >/dev/null &

    fi

}

app_start() {

    if killall -q -0 smartdns; then
        killall smartdns
        return
    fi

    echo "1" >$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/smartdns

    start

}

stop() {
    killall smartdns
    rm $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/smartdns
}

config() {
    if [ -f /tmp/iktmp/import/file ]; then
        filesize=$(stat -c%s "/tmp/iktmp/import/file")
        if [ $filesize -lt 524288 ]; then
            rm $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
            mv /tmp/iktmp/import/file $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
            killall smartdns
            # start
        fi

    fi

}

#echo "All Parameters: $@" >> /tmp/smartdnszzz.log

update_server() {

    [ $ipBlacklist == "true" ] && ipBlacklist='-blacklist-ip' || ipBlacklist=''
    [ -n "$group" ] && group="-group ${group}"
    [ -n "$dnsPort" ] && dnsIp=${dnsIp}:${dnsPort}

    echo ${protocol} ${dnsIp} ${group} ${ipBlacklist} ${extraParams} >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf

}

delete_server() {

    #echo "All Parameters: $@" >> /tmp/smartdnszzz2.log
    #rowIndex=${rowIndex}

    line_numbers=$(grep -n "$dnsIp" /etc/smartdns/smartdns.conf | cut -d: -f1)

    for line in $line_numbers; do
        sed -i "${line}d" /etc/smartdns/smartdns.conf
    done

    #sed -i "${rowIndex}d" /tmp/smartdnstest.config  # 删除指定行

}

__show_getconfig() {
    id=1
    cat /etc/smartdns/smartdns.conf | grep "server" | grep -v "server-name" | grep -v "#" | grep "^server" >/tmp/smardns.tmp.log
    cat /etc/smartdns/smartdns.conf | grep "server" | grep -v "server-name" | grep -v "#" | grep "^nameserver" >>/tmp/smardns.tmp.log
    while IFS= read -r line; do
        read -ra tokens <<< "$line"

        # 初始化字段
        dnsIp='' 
        protocol=''
        dnsPort='默认'
        group='默认'
        ipBlacklist=false
        extraParams=''

        # 解析主类型和地址
        protocol="${tokens[0]}"
        [ $protocol == "server" ] && protocol=UDP
        [ $protocol == "server-https" ] && protocol=HTTPS
        [ $protocol == "nameserver" ] && protocol=DOH
        [ $protocol == "server-tcp" ] && protocol=TCP
        [ $protocol == "server-tls" ] && protocol=TLS

        dnsIp="${tokens[1]}"
        if [[ "$dnsIp" == *:* ]] && [[ "$dnsIp" != *https:* ]] && [[ "$dnsIp" != *tls:* ]]; then
            dnsPort=$(echo "$dnsIp" | awk -F ":" '{print $2}')
            dnsIp=$(echo "$dnsIp" | awk -F ":" '{print $1}')
        fi
        # 解析附加参数
        for ((i = 2; i < ${#tokens[@]}; i++)); do
            case "${tokens[i]}" in
                -group) group="${tokens[i+1]}"; ((i++)) ;;
                -name) name="${tokens[i+1]}"; ((i++)) ;;
                -blacklist-ip) ipBlacklist=true ;;
                *) extraParams="${extraParams:+ }${tokens[i]}" ;;
            esac
        done

        local id$id=$(json_output id:int dnsIp:str protocol:str dnsPort:str group:str ipBlacklist:bool extraParams:str)
        json_append __json_result__ id$id:json
        id=$((id + 1))
    done </tmp/smardns.tmp.log

}

update_config() {

    echo "All Parameters: $@" >/tmp/smartdnsaaa.log
    echo "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf" >>/tmp/smartdnsaaa.log

    cat /etc/smartdns/smartdns.conf | grep "server" | grep -v "server-name" | grep -v "#" | grep "^server" >/tmp/smardns.tmp.log
    cat /etc/smartdns/smartdns.conf | grep "server" | grep -v "server-name" | grep -v "#" | grep "^nameserverr" >>/tmp/smardns.tmp.log

    echo server-name ${serverName} >$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 服务器名称

    echo "bind :${localPort}" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # IPV6 服务器
    if [ ${tcpServer} == "true" ]; then
        echo "bind-tcp :${localPort}" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
    fi

    if [ ${dualStackIP} == "false" ]; then
        echo '#关闭双栈 IP 优选' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
        echo 'dualstack-ip-selection no' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 双栈 IP 优选
    fi

    if [ ${domainPreload} == "true" ]; then
        echo '# 开启域名预加载' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
        echo 'prefetch-domain yes' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 域名预加载
    fi

    if [ ${cacheExpire} == "true" ]; then
        echo 'serve-expired yes' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 缓存过期服务
    fi

    if [ ! -z $cacheExpire ]; then
        echo "cache-size ${cacheSize}" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 缓存大小
    fi

    #if [ ${resolveLocalHost} == "true" ];then
    #	echo 'dnsmasq-lease-file /tmp/dhcp.leases' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf 				# 解析本地主机名
    #fi

    if [ $disableIpv6 == "true" ] && [ $disableHttps == "true" ]; then
        echo 'force-qtype-SOA  28 65' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf

    else

        if [ ${disableIpv6} == "true" ]; then
            echo 'force-qtype-SOA  28' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 停用 IPV6 地址解析   未找到
        fi

        if [ ${disableHttps} == "true" ]; then
            echo 'force-qtype-SOA  65' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 停用 HTTPS 地址解析  未找到
        fi

    fi

    <<EOF
if [ ${autoDnsmasq} == "true" ];then
                autoDnsmasq: false       # 自动设置 Dnsmasq     未找到
fi
EOF

    if [ ! -z $domainTTL ]; then
        echo "rr-ttl ${domainTTL}" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 域名 TTL
    fi

    if [ ! -z $domainTTLMin ]; then
        echo "rr-ttl-min ${domainTTLMin}" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 域名 TTL 最小值
    fi

    if [ ! -z $domainTTLMax ]; then
        echo "rr-ttl-max ${domainTTLMax}" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 域名 TTL 最大值
    fi
    if [ ! -z $responseTTLMax ]; then
        echo "rr-ttl-reply-max ${responseTTLMax}" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf # 回应的域名 TTL 最大值
    fi

    echo '#设置日志文件' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
    echo 'log-level error' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
    echo 'log-size 64k' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
    echo 'log-num 0' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf

    echo '#引入中国域名列表' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
    echo 'conf-file /etc/smartdns/cn.conf' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf

    cat /tmp/smardns.tmp.log >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf

    echo '#自定义配置' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
    echo 'conf-file /etc/smartdns/address.conf' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
    echo 'conf-file /etc/smartdns/blacklist-ip.conf' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
    echo 'conf-file /etc/smartdns/custom.conf' >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf

    if [ "$skipTest" == "true" ]; then
        skipTest='-no-speed-check'
    else
        skipTest=''
    fi
    if [ "$skipAddressRule" == "true" ]; then
        skipAddressRule='-no-rule-addr'
    else
        skipAddressRule=''
    fi
    if [ "$skipNameserverRule" == "true" ]; then
        skipNameserverRule='-no-rule-nameserver'
    else
        skipNameserverRule=''
    fi
    if [ "$skipIPsetRule" == "true" ]; then
        skipIPsetRule='-no-rule-ipset'
    else
        skipIPsetRule=''
    fi
    if [ "$skipAddressSOARule" == "true" ]; then
        skipAddressSOARule='-no-rule-soa'
    else
        skipAddressSOARule=''
    fi
    if [ "$skipDualStack" == "true" ]; then
        skipDualStack='-no-dualstack-selection'
    else
        skipDualStack=''
    fi
    if [ "$skipCache" == "true" ]; then
        skipCache='-no-cache'
    else
        skipCache=''
    fi
    if [ "$disableIPv62" == "true" ]; then
        disableIPv62='-force-aaaa-soa'
    else
        disableIPv62=''

    fi

    if [ ! -z "$serverGroup" ]; then
        serverGroup1='-group '$serverGroup
        serverGroup=$serverGroup1
    else
        serverGroup=''
    fi

    if [ "$enable" == "true" ]; then

        if [ ${ipv6Server} == "true" ]; then

            if [ "$tcpServer2" == "true" ]; then
                echo "bind [::]:${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
                echo "bind-tcp [::]:${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
            else
                echo "bind [::]:${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
            fi

        else

            if [ "$tcpServer2" == "true" ]; then
                echo "bind :${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf
                echo "bind-tcp :${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf

            else
                echo "bind :${localPort2} $skipTest $serverGroup $skipAddressRule $skipNameserverRule $skipIPsetRule $skipAddressSOARule $skipDualStack $skipCache $disableIPv62" >>$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/smartdns.conf

            fi
        fi

    fi

}

show() {

    Show __json_result__
}

__show_status() {
    local status=0

    if killall -q -0 smartdns; then
        local status=1
    fi
    json_append __json_result__ status:int

    serverName=$(cat /etc/smartdns/smartdns.conf | grep "^server-name" | awk '{print $2}')

    domainTTL=$(cat /etc/smartdns/smartdns.conf | grep "^rr-ttl " | awk '{print $2}')

    domainTTLMin=$(cat /etc/smartdns/smartdns.conf | grep "^rr-ttl-min " | awk '{print $2}')
    domainTTLMax=$(cat /etc/smartdns/smartdns.conf | grep "^rr-ttl-max " | awk '{print $2}')
    responseTTLMax=$(cat /etc/smartdns/smartdns.conf | grep "^rr-ttl-reply-max " | awk '{print $2}')

    ipv6Server=$(cat /etc/smartdns/smartdns.conf | grep "\[::\]" | wc -l)
    if [ $ipv6Server -ne 0 ]; then
        ipv6Server=true
    else
        ipv6Server=false
    fi

    dualStackIP=$(cat /etc/smartdns/smartdns.conf | grep "^dualstack-ip-selection" | wc -l)
    if [ $dualStackIP -eq 0 ]; then
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

    tcpServer=$(cat /etc/smartdns/smartdns.conf | grep "^bind-tcp " | wc -l)
    if [ $tcpServer -ne 0 ]; then
        tcpServer=true
    else
        tcpServer=false
    fi

    domainPreload=$(cat /etc/smartdns/smartdns.conf | grep "^prefetch-domain " | wc -l)
    if [ $domainPreload -ne 0 ]; then
        domainPreload=true
    else
        domainPreload=false
    fi

    cacheExpire=$(cat /etc/smartdns/smartdns.conf | grep "^serve-expired " | wc -l)
    if [ $cacheExpire -ne 0 ]; then
        cacheExpire=true
    else
        cacheExpire=false
    fi

    resolveLocalHost=$(cat /etc/smartdns/smartdns.conf | grep "^dnsmasq-lease-file " | wc -l)
    if [ $resolveLocalHost -ne 0 ]; then
        resolveLocalHost=true
    else
        resolveLocalHost=false
    fi

    disableIpv6_status=$(cat /etc/smartdns/smartdns.conf | grep "^force-qtype-SOA" | wc -l)
    if [ $disableIpv6_status -ne 0 ]; then

        disableHttps1=$(cat /etc/smartdns/smartdns.conf | grep "^force-qtype-SOA" | grep "65" | wc -l)
        if [ $disableHttps1 -ne 0 ]; then
            disableHttps=true
        else
            disableHttps=false

        fi

        disableIpv61=$(cat /etc/smartdns/smartdns.conf | grep "^force-qtype-SOA" | grep "28" | wc -l)
        if [ $disableIpv61 -ne 0 ]; then
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
            if [ ! -z "localPort2" ]; then
                server_tcp_num=$(grep ":${localPort2}" /etc/smartdns/smartdns.conf | wc -l)
                if [ $server_tcp_num -eq 2 ]; then
                    tcpServer2=true
                else
                    tcpServer2=false
                fi
                server2-tcp=$(grep ":5353" /etc/smartdns/smartdns.conf | wc -l)
            fi

            enable=true

            skipIPsetRule=$(echo "$bind_lines" | grep 'no-speed-check' | wc -l)
            if [ $skipIPsetRule -ne 0 ]; then
                skipIPsetRule=true
            else
                skipIPsetRule=false
            fi

            serverGroup=$(echo "$bind_lines" | grep "group" | wc -l)
            if [ $serverGroup -ne 0 ]; then
                serverGroup=$(echo "$bind_lines" | awk -F "-group" '{print $2}' | awk -F " " '{print $1}' | xargs)
            fi

            skipTest=$(echo "$bind_lines" | grep 'no-speed-check' | wc -l)
            if [ $skipTest -ne 0 ]; then
                skipTest=true
            else
                skipTest=false
            fi

            skipAddressRule=$(echo "$bind_lines" | grep "no-rule-addr" | wc -l)
            if [ $skipAddressRule -ne 0 ]; then
                skipAddressRule=true
            else
                skipAddressRule=false
            fi

            skipNameserverRule=$(echo "$bind_lines" | grep "no-rule-nameserver" | wc -l)
            if [ $skipNameserverRule -ne 0 ]; then
                skipNameserverRule=true
            else
                skipNameserverRule=false
            fi

            skipIPsetRule=$(echo "$bind_lines" | grep "no-rule-ipset" | wc -l)
            if [ $skipIPsetRule -ne 0 ]; then
                skipIPsetRule=true
            else
                skipIPsetRule=false
            fi

            skipAddressSOARule=$(echo "$bind_lines" | grep "no-rule-soa" | wc -l)
            if [ $skipAddressSOARule -ne 0 ]; then
                skipAddressSOARule=true
            else
                skipAddressSOARule=false
            fi

            skipDualStack=$(echo "$bind_lines" | grep "no-dualstack-selection" | wc -l)
            if [ $skipDualStack -ne 0 ]; then
                skipDualStack=true
            else
                skipDualStack=false
            fi

            skipCache=$(echo "$bind_lines" | grep "no-cache" | wc -l)
            if [ $skipCache -ne 0 ]; then
                skipCache=true
            else
                skipCache=false
            fi
            ipv6Server2=$(echo "$bind_lines" | grep "force-aaaa-soa" | wc -l)
            if [ $ipv6Server2 -ne 0 ]; then
                ipv6Server2=true
            else
                ipv6Server2=false
            fi
        fi

    else
        localPort=$(cat /etc/smartdns/smartdns.conf | grep "^bind " | awk -F ":" '{print $NF}')
        enable=false

    fi

    cacheSize=$(cat /etc/smartdns/smartdns.conf | grep "^cache-size" | awk '{print $2}')

    # 目标文件路径
    FILE_PATH="/etc/smartdns/smartdns.conf"

    # 检查文件是否存在
    if [ -f "$FILE_PATH" ]; then
        encoded_content=$(base64 "$FILE_PATH" | tr -d '\n')
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

config() {

    if [ -f /tmp/iktmp/import/file ]; then

        mv /tmp/iktmp/import/file $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config/$Filename

    fi

}

case "$1" in
start)
    start
    ;;
stop)
    stop
    ;;
*) ;;
esac


Command()
{

    if [ ! "$1" ];then
        return 0
    fi
    if ! declare -F "$1" >/dev/null 2>&1 ;then
        echo "unknown command ($1)"
        return 1
    fi

    local i
    for i in "${@:2}" ;do
        if [[ "$i" =~ ^([^=]+)=(.*) ]];then
            # 将值赋给以键命名的变量
            eval "${BASH_REMATCH[1]}='${BASH_REMATCH[2]}'"
        fi
    done

    $@
}

declare -A ___INCLUDE_ALREADY_LOAD_FILE___
declare -A ___JSON_ALREADY_LOAD_FILE___
declare -A ___I18N_ALREADY_LOAD_FILE___
declare -A CONVERT_NETMASK_TO_BIT
declare -A CHECK_IS_SETING
declare -A APPIDS
declare -A VERSION_ALL
declare -A SYSSTAT_MEM
declare -A SYSSTAT_STREAM
declare -A IK_HOSTS_UPDATE

LINE_R=$'\r'
LINE_N=$'\n'
LINE_RN=$'\r\n'
LINE_NT=$'\n\t'

IK_DIR_CONF=/etc/mnt/ikuai
IK_DIR_DATA=/etc/mnt/data
IK_DIR_BAK=/etc/mnt/bak
IK_DIR_LOG=/etc/log
IK_DIR_SCRIPT=/usr/ikuai/script
IK_DIR_INCLUDE=/usr/ikuai/include
IK_DIR_FUNCAPI=/usr/ikuai/function
IK_DIR_LIBPROTO=/usr/libproto
IK_DIR_TMP=/tmp/iktmp
IK_DIR_CACHE=/tmp/iktmp/cache
IK_DIR_LANG=/tmp/iktmp/LANG
IK_DIR_I18N=/etc/i18n
IK_DIR_IMPORT=/tmp/iktmp/import
IK_DIR_EXPORT=/tmp/iktmp/export
IK_DIR_HOSTS=/tmp/iktmp/ik_hosts
IK_DIR_BASIC_NOTIFY=/etc/basic/notify.d
IK_DIR_VRRP=/tmp/iktmp/vrrp

IK_DB_CONFIG=$IK_DIR_CONF/config.db
IK_DB_SYSLOG=$IK_DIR_LOG/syslog.db
IK_DB_COLLECTION=$IK_DIR_LOG/collection.db
IK_AC_PSK_DB=$IK_DIR_CONF/wpa_ppsk.db

Syslog()
{
	logger -t sys_event "$*"
}

Include()
{
	local file
	for file in ${@//,/ } ;do
		if [ ! "${___INCLUDE_ALREADY_LOAD_FILE___[$file]}" ];then
			___INCLUDE_ALREADY_LOAD_FILE___[$file]=1
			. $IK_DIR_INCLUDE/$file ""
		fi
	done
}

I18nload()
{
	local file
	for file in ${@//,/ } ;do
		if [ ! "${___I18N_ALREADY_LOAD_FILE___[$file]}" ];then
			if [ ! -f $IK_DIR_CACHE/i18n/$file.sh ];then
				json_decode_file_to_cache i18n_${file%%.*} $IK_DIR_I18N/$file $IK_DIR_CACHE/i18n/$file.sh
			fi

			___I18N_ALREADY_LOAD_FILE___[$file]=1
			. $IK_DIR_CACHE/i18n/$file.sh 2>/dev/null
		fi
	done
}

Show()
{
	local ____TYPE_SHOW____
	local ____SHOW_TOTAL_AND_DATA____
	local TYPE=${TYPE:-data}

	for ____TYPE_SHOW____ in ${TYPE//,/ } ;do
		if ! __show_$____TYPE_SHOW____ ;then
			if ! declare -F __show_$____TYPE_SHOW____ >/dev/null 2>&1 ;then
				echo "unknown TYPE ($____TYPE_SHOW____)" ;return 1
			fi
		fi
	done

	eval echo -n \"\$$1\"
}

json_output()
{
	if [ -n "$*" ];then
		local __json
		for param in $* ;do
			case "${param//*:}" in
			  bool) __json+="${__json:+,}\\\"${param//:*}\\\":\${${param//:*}:-false}" ;;
			  int) __json+="${__json:+,}\\\"${param//:*}\\\":\${${param//:*}:-0}" ;;
			  str) __json+="${__json:+,}\\\"${param//:*}\\\":\\\"\${${param//:*}//\\\"/\\\\\\\"}\\\"" ;;
			 json) __json+="${__json:+,}\\\"${param//:*}\\\":\${${param//:*}:-\{\}}" ;;
			 join) __json+="\${${param//:*}:+,\$${param//:*}}" ;;
			esac
		done
		eval echo -n \"\{$__json\}\"
	fi
}

json_append()
{
	if [ -n "$2" ];then
		local __json
		for param in ${@:2} ;do
			case "${param//*:}" in
			  int) __json+="${__json:+,}\\\"${param//:*}\\\":\${${param//:*}:-0}" ;;
			  str) __json+="${__json:+,}\\\"${param//:*}\\\":\\\"\${${param//:*}//\\\"/\\\\\\\"}\\\"" ;;
			 json) __json+="${__json:+,}\\\"${param//:*}\\\":\${${param//:*}:-\{\}}" ;;
			 join) __json+="\${${param//:*}:+,\$${param//:*}}" ;;
			esac
		done
		eval eval \$1="{\'\${$1:1:\${#$1}-2}\'\${$1:+,}\${__json}}"
	fi
}

Include json.sh,fsyslog.sh,sqlite.sh,check_varl.sh

Command $@
