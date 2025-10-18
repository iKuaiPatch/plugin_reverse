#!/bin/bash
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
PLUGIN_NAME=vremote
. /etc/mnt/plugins/configs/config.sh
. /etc/release
. /usr/ikuai/include/sys/sysstat.sh

[ $ARCH = "mips" ] && platform="mt7621"
[ $ARCH = "arm" ] && platform="mt798x"
[ $ARCH = "x86" ] && platform="x86"

configData=$(cat $EXT_PLUGIN_CONFIG_DIR/vremote/config)
apiUrl=$(echo $configData | base64 -d | awk -F '|' '{print($1)}')
apiToken=$(echo $configData | base64 -d | awk -F '|' '{print($2)}' | base64 -d)
shareCode=$(cat $EXT_PLUGIN_CONFIG_DIR/vremote/sharecode)
hostname=$(echo "$apiUrl" | awk -F/ '{print $3}' | cut -d: -f1)

debug() {
	debuglog=$( [ -s /tmp/debug_on ] && cat /tmp/debug_on || echo -n /tmp/debug.log )
    if [ "$1" = "clear" ]; then
        rm -f $debuglog && return
    fi

    if [ -f /tmp/debug_on ]; then
        TIME_STAMP=$(date +"%Y%m%d %H:%M:%S")
        echo "[$TIME_STAMP]: PL> $1" >>$debuglog
    fi
}

# 确保不被重复执行
exit_if_running() {
    pidfile="/tmp/iktmp/vremote.pid"
    if [ -f "$pidfile" ]; then
        old_pid=$(cat "$pidfile")
        if kill -0 "$old_pid" 2>/dev/null; then
            debug "脚本已经在运行，退出"
            exit
        fi
    fi
    echo $$ > "$pidfile"
    trap "rm -f $pidfile" EXIT
}

# 检查网络状态，直到网络连接成功才继续向下执行
check_network() {
    debug "开始检查网络状态"
    while true; do
        ping -c2 qq.com >/dev/null 2>&1 && break
        ping -c2 163.com >/dev/null 2>&1 && break
        ping -c2 baidu.com >/dev/null 2>&1 && break
        sleep 20
    done
    debug "网络连接正常，继续运行"
    return 0
}

add_crontab(){
    debug "开始检查定时任务"
    vnlcro=`cat /etc/crontabs/root | grep "vremote" | wc -l`
    if [ $vnlcro -eq 0 ]; then
        # 定时任务作为守护线程，每60分钟执行一次
        cronTask="20 * * * * vremote $1 $2"
        echo "$cronTask" >>/etc/crontabs/cron.d/vremote
        echo  "$cronTask" >>/etc/crontabs/root
        crontab /etc/crontabs/root
    fi

    crondproc=`ps | grep crond | grep -v grep | wc -l`
    if [ $crondproc -eq 0 ]; then
        crond -L /dev/null
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

# 生成随机网段
generate_random_subnet() {
    case $((RANDOM % 2)) in
        0)
            first_octet=10
            second_octet=$((RANDOM % 256))
            third_octet=$((RANDOM % 256))
            ;;
        1)
            first_octet=172
            second_octet=$((RANDOM % 16 + 16))  # 16-31
            third_octet=$((RANDOM % 256))
            ;;
    esac

    echo "$first_octet.$second_octet.$third_octet"
}

enable_pptp_server() {
    # 开启PPTP服务
    PID=$(pidof pptpd | awk '{print $NF}')
    if [ -n "$PID" ]; then
        debug "PPTP服务已启动，跳过启动步骤"
        addr_pool=$(sqlite3 /etc/mnt/ikuai/config.db "select addr_pool from pptp_server where id=1;")
    else
        debug "PPTP服务未启动，开始启动"
        subnet=$(generate_random_subnet)
        server_ip="${subnet}.1"
        addr_pool="${subnet}.2-${subnet}.254"
        server_port=1723
        dns1="114.114.114.114"
        dns2="119.29.29.29"
        
        params="server_ip=$server_ip server_port=$server_port dns1=$dns1 dns2=$dns2 addr_pool=$addr_pool \
                id=1 enabled=yes open_mppe=2 mtu=1400 mru=1400"
        /usr/ikuai/function/pptp_server save $params
    fi

    nol2rt=$(sqlite3 /etc/mnt/ikuai/config.db "select nol2rt from acl_l2route where id=1;")
    params="id=1 ttl_num=1 nol2rt=$nol2rt nol2rt_ip=$addr_pool times=00:00-23:59"
    /usr/ikuai/function/acl_l2route save $params
}

sync_for_share_servermode() {

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/vremote/enableProxy ]; then
        debug "未启用共享服务，跳过共享配置同步"
        return -1
    fi

    local virtualIp=$(vnt --info | grep 'Virtual ip' | awk -F ': ' '{print($2) }')
    if [ -z "$virtualIp" ]; then
        debug "VNT未运行，跳过共享配置同步"
        return -1
    fi

    debug "开始获取本设备共享配置"
    data="[]"
    dataCount=0

    result=$(curl --location "$apiUrl/api/share/deviceconfig/$GWID" \
        --header "Authorization: Bearer $apiToken")
    
    success=$(echo $result | jq -r '.success')
    if [ "$success" != "true" ]; then
        debug "获取本设备共享配置失败"
        return -1
    else
        data=$(echo $result | jq -c '.data')
        dataCount=$(echo "$data" | jq -c '.[]' | wc -l)
        debug "获取本设备共享配置成功，共享配置数量: $dataCount"
    fi

    # 如果data长度大于0 则调用 enable_pptp_server 函数
    if [ $dataCount -gt 0 ]; then
        enable_pptp_server
    fi

    # 找出pppuser表中username字段值不在data中的记录的id，并删除
    if [ $dataCount -gt 0 ]; then
        usernames=$(echo "$data" | jq -r '.[].userName' | sed "s/^/'/;s/$/'/" | tr '\n' ',' | sed 's/,$//')
        ids=$(sqlite3 /etc/mnt/ikuai/config.db "select id from pppuser where username not in ($usernames) and comment='vproxy';" | tr '\n' ',' | sed 's/,$//')
    else
        ids=$(sqlite3 /etc/mnt/ikuai/config.db "select id from pppuser where comment='vproxy';" | tr '\n' ',' | sed 's/,$//')
    fi
    
    if [ -n "$ids" ]; then
        debug "开始删除不再共享配置中的PPTP拨号连接！ 连接ID: $ids"
        /usr/ikuai/function/pppuser del id=$ids
    fi

    echo "$data" | jq -c '.[]' | while read -r dataline; do

        username=$(echo "$dataline" | jq -r '.userName')
        password=$(echo "$dataline" | jq -r '.password')
        expire=$(echo "$dataline" | jq -r '.expireTime')
        upload=$(echo "$dataline" | jq -r '.upload')
        download=$(echo "$dataline" | jq -r '.download')

        [ "$upload" ] || upload=0
        [ "$download" ] || download=0

        upload=$(($upload * 1024))
        download=$(($download * 1024))
        expire=$(date -d "$expire" +%s) || expire=0

        debug "开始创建或更新PPTP账户！ 配置行内容: $username|$password|$expire|$upload|$download"

        # 新建或更新本地账户
        id=$(sqlite3 /etc/mnt/ikuai/config.db "select id from pppuser where username='$username';")
        ppptype="pptp"
        if [ -z "$id" ]; then
            debug "新建用户: $username"
            params="enabled=yes comment=vproxy username=$username passwd=$password expires=$expire start_time=$(date +%s) \
                create_time=$(date +%s) ppptype=$ppptype share=10 auto_mac=0 upload=$upload download=$download packages=0 bind_vlanid=0 bind_ifname=any"
            /usr/ikuai/function/pppuser add $params
        else
            debug "更新用户: $username"
            params="enabled=yes comment=vproxy id=$id username=$username passwd=$password expires=$expire start_time=0 create_time=0 \
                ppptype=$ppptype share=10 auto_mac=0 upload=$upload download=$download packages=0 bind_vlanid=0 bind_ifname=any auto_vlanid=1 last_conntime=0"
            /usr/ikuai/function/pppuser edit $params
        fi
    done
}

sync_for_share_clientmode() {

    debug "开始获取共享分组配置"
    data="[]"
    dataCount=0

    if [ -n "$shareCode" ]; then
        result=$(curl --location "$apiUrl/api/share/groupconfig/$shareCode" \
        --header "Authorization: Bearer $apiToken" \
        --header "deviceId: $GWID")
    
        success=$(echo $result | jq -r '.success')
        if [ "$success" != "true" ]; then
            debug "获取共享分组配置失败，共享代码: $shareCode"
            return -1
        else
            data=$(echo $result | jq -c '.data')
            dataCount=$(echo $data | jq -c '.[]' | wc -l)
            debug "获取共享分组配置成功，共享代码: $shareCode，共享分组配置数量: $dataCount"
        fi
    fi

    # 找出pptp_client表中server字段值不在data中的记录的id，并删除
    if [ $dataCount -gt 0 ]; then
        servers=$(echo "$data" | jq -r '.[].server' | sed "s/^/'/;s/$/'/" | tr '\n' ',' | sed 's/,$//')
        ids=$(sqlite3 /etc/mnt/ikuai/config.db "select id from pptp_client where server not in ($servers) and comment='vproxy';"| tr '\n' ',' | sed 's/,$//')
    else
        ids=$(sqlite3 /etc/mnt/ikuai/config.db "select id from pptp_client where comment='vproxy';"| tr '\n' ',' | sed 's/,$//')
    fi
    
    if [ -n "$ids" ]; then
        debug "开始删除不再共享配置中的PPTP拨号连接！ 连接ID: $ids"
        /usr/ikuai/function/pptp_client del id=$ids
    fi

    echo "$data" | jq -c '.[]' | while read -r dataline; do

        server=$(echo "$dataline" | jq -r '.server')
        username=$(echo "$dataline" | jq -r '.userName')
        password=$(echo "$dataline" | jq -r '.password')
        name=pptp_$(echo "$server" | sed 's/\.//g')

        debug "开始创建或更新PPTP拨号连接！ 配置行内容: $server|$username|$password|$name"

        if [ -z "$server" ]; then
            debug "共享配置中没有找到服务器地址，跳过创建或更新PPTP拨号连接"
            continue
        fi

        # 新建或更新PPTP连接
        id=$(sqlite3 /etc/mnt/ikuai/config.db "select id from pptp_client where server='$server';")
        if [ -z "$id" ]; then
            debug "新建连接: $server"
            params="enabled=yes comment=vproxy name=$name username=$username passwd=$password server=$server server_port=1723 \
                interface=auto mtu=1400 mru=1400 timing_rst_switch=0 timing_rst_week=1234567 timing_rst_time=00:00,, cycle_rst_time=0"
            /usr/ikuai/function/pptp_client add $params
        else
            debug "更新连接: $server"
            old=$(sqlite3 /etc/mnt/ikuai/config.db "select username,passwd from pptp_client where id='$id';")
            if [ "$old" != "$username|$password" ]; then
                debug "用户名或密码发生变化，更新用户名或密码！"
                params="enabled=yes comment=vproxy id=$id name=$name username=$username passwd=$password server=$server server_port=1723 \
                    interface=auto mtu=1400 mru=1400 timing_rst_switch=0 timing_rst_week=1234567 timing_rst_time=00:00,, cycle_rst_time=0"
                    /usr/ikuai/function/pptp_client edit $params
            else
                debug "用户名或密码未发生变化，跳过更新！"
            fi
        fi
    done
}

push_stats_data(){
    local data=""
    local stats_data=""

    debug "开始获取同步数据"

    if [ $ARCH = "x86" ]; then
        uuid=$(cat /sys/class/dmi/id/product_uuid | md5sum | tr '[:lower:]' '[:upper:]')
        machineCode=$(hexdump -v -s $((0x88)) -n 4 -e '1/1 "%02X"' /dev/${BOOTHDD}2)${uuid:5:8}
    else
        local eep_mtd=/dev/$(cat /proc/mtd | grep "Factory" | cut -d ":" -f 1)
        machineCode=$(hexdump -v -s $((0x88 + $EMBED_FACTORY_PART_OFFSET)) -n 4 -e '1/1 "%02X"' $eep_mtd)
    fi
    json_append stats_data machineCode:str

    local virtualIp=$(vnt --info | grep 'Virtual ip' | awk -F ': ' '{print($2) }')
    json_append stats_data virtualIp:str
    # debug "VNT虚拟IP获取成功: $virtualIp"

    local publicIp=$(wget -qO- --no-check-certificate "http://members.3322.org/dyndns/getip")
    json_append stats_data publicIp:str
    # debug "公网IP获取成功: $publicIp"

    local webPorts=$(sqlite3 /etc/mnt/ikuai/config.db "select http_port,https_port from remote_control;")
    json_append stats_data webPorts:str
    # debug "webPorts: $webPorts"

    local uptime=$(awk -F '[\.| ]' '{print $1}' /proc/uptime)
    json_append stats_data uptime:int
    # debug "系统启动时间: $uptime"

    local cpuUsage=$(cat /tmp/iktmp/monitor-ikstat/cpu | head -n 1 | awk -F ' ' '{print $2}')
    json_append stats_data cpuUsage:str
    # debug "CPU使用率: $cpuUsage"

    local cpuTemp=$(cat /tmp/iktmp/cputemp/0 2>/dev/null)
    if [[ "$cpuTemp" =~ ^[0-9]+$ ]];then
        cpuTemp=$((cpuTemp/1000))
    else
        cpuTemp=0
    fi
    json_append stats_data cpuTemp:int
    # debug "CPU温度: $cpuTemp"

    local totalmem=$(cat /proc/meminfo | grep MemTotal | awk -F ' ' '{print $2}')
    local availmem=$(cat /proc/meminfo | grep MemAvailable | awk -F ' ' '{print $2}')
    local memoryUsage=$(((totalmem-availmem)*100/totalmem))%
    json_append stats_data memoryUsage:str
    # debug "内存使用率: $memoryUsage"

    local total_conn=$(cat /proc/sys/net/netfilter/nf_conntrack_count)
    local uploadRate=$(cat /proc/ikuai/stats/ik_proto_stats | tail -n 1 | awk -F ' ' '{print $3}')
    local downloadRate=$(cat /proc/ikuai/stats/ik_proto_stats | tail -n 1 | awk -F ' ' '{print $4}')
    json_append stats_data total_conn:int
    json_append stats_data uploadRate:int
    json_append stats_data downloadRate:int

    local res=$(iktimerc ".load_hosts; select count() count from online_user;")
    local online_user_count=$(echo $res | awk -F '=' '{print $2}')
    json_append stats_data online_user_count:int

    local total_24h_download=$(sqlite3 /etc/log/collection.db "select sum(Total) from app_flow where timestamp > strftime('%s','now')- 24*60*60;")
    json_append stats_data total_24h_download:int

    local hostname=$(hostname)
    json_append stats_data hostname:str
    json_append stats_data DEVICE_MAC:str
    json_append stats_data GWID:str
    json_append stats_data VERSION:str

    local rttyInd=1
    json_append stats_data rttyInd:int

    json_append data stats_data:json

    local lastSyncLogId=$(cat $EXT_PLUGIN_CONFIG_DIR/vremote/lastSyncLogId 2>/dev/null || echo 0)
    if [ $lastSyncLogId -eq 0 ]; then
        lastSyncLogId=$(sqlite3 /etc/log/syslog.db "select max(id) from sys_event;")
        local sys_logs=$(sqlite3 /etc/log/syslog.db "select id,timestamp,content from sys_event where id > $lastSyncLogId - 10 order by id desc;")
    else
        local sys_logs=$(sqlite3 /etc/log/syslog.db "select id,timestamp,content from sys_event where id > $lastSyncLogId and id <= $lastSyncLogId + 10 order by id desc;")
        lastSyncLogId=$((lastSyncLogId + 10))
    fi  
        
    local logsdata=""
    if [ -n "$sys_logs" ]; then
        while IFS= read -r logline || [ -n "$logline" ]; do
            id=$(echo $logline | awk -F '|' '{print $1}')
            logtime=$(echo $logline | awk -F '|' '{print $2}')
            logcontent=$(echo $logline | awk -F '|' '{print $3}')
            _json="{\"id\":\"$id\",\"timestamp\":\"$logtime\",\"content\":\"$logcontent\"}"
            logsdata+="${logsdata:+,}$_json"
        done <<< "$sys_logs"
    fi
    sys_logs="[$logsdata]"
    json_append data sys_logs:json

    local plugins=""
    for f in $(ls /usr/ikuai/www/plugins) ;do
        if _json=$(cat /usr/ikuai/www/plugins/$f/metadata.json) ;then
            pluginName=$(echo $_json | jq -r '.name')
            plugins+="${plugins:+,}\"$pluginName\""
        fi  
    done
    plugins="[$plugins]"
    json_append data plugins:json

    debug "获取同步数据完成"

    debug "开始推送数据"
    
    debug "apiUrl: $apiUrl"
    debug "apiToken: $apiToken"
    debug "GWID: $GWID"
    debug "推送数据: $data"
    result=$(curl --location -X PUT "$apiUrl/api/device/reportstatus/$GWID" \
        --header "Authorization: Bearer $apiToken" \
        --header "Content-Type: application/json" \
        --data "$data")

    success=$(echo $result | jq -r '.success')

    if [ "$success" = "true" ]; then
        debug "推送数据成功：$result"
        echo $(date +"%Y-%m-%d %H:%M") > $EXT_PLUGIN_CONFIG_DIR/vremote/lastSyncTime
        echo $lastSyncLogId > $EXT_PLUGIN_CONFIG_DIR/vremote/lastSyncLogId
        rm -f $EXT_PLUGIN_LOG_DIR/vremote_error
    else
        debug "推送数据失败：$result"
        touch $EXT_PLUGIN_LOG_DIR/vremote_error
    fi
}

connect_rtty_server() {

    # 如果vrtty进程已经存在，则不重复启动
    pidof vrtty && return 

    # 如果rtty未安装，则尝试安装
    [ -f /usr/sbin/rtty ] || try_insatll_rtty || return
    
    debug "开始连接rtty服务"
    if [ -L /usr/sbin/rtty ]; then
        ln -sf $(readlink /usr/sbin/rtty) /usr/sbin/vrtty
    else
        ln -sf /usr/sbin/rtty /usr/sbin/vrtty
    fi
    ln -sf /etc/setup/rc /bin/login
    geoaddr=$(curl -s "http://my.ip.cn/json/" | jq -r '"\(.data.province)\(.data.city)\(.data.district)-\(.data.isp)"')
    vrtty -d "$platform|$(hostname)|$geoaddr" -I "$GWID" -h $hostname -p 5912 -s -a -C /usr/ikuai/cert.pem &
}

try_insatll_rtty()
{ 
	debug "rtty未安装，开始安装"
	if [ ! -f $EXT_PLUGIN_CONFIG_DIR/vremote/bin/rtty ]; then
		mkdir -p $EXT_PLUGIN_CONFIG_DIR/vremote/bin

		success=0
		for i in {1..3}; do
			wget -O /tmp/rtty.tar.gz ${RMT_PLUGIN_BASE_URL%/plugins/release}/resources/RTTY/rtty-${platform}.tar.gz
			if [ $? -eq 0 ]; then
				success=1
				break
			fi
		done
		if [ $success -eq 0 ]; then
			debug "rtty下载失败, 退出安装！"
			return 1
		fi
		tar -xzf /tmp/rtty.tar.gz -C $EXT_PLUGIN_CONFIG_DIR/vremote/bin 
		rm -f /tmp/rtty.tar.gz 
	fi
	
	ln -sf $EXT_PLUGIN_CONFIG_DIR/vremote/bin/rtty /usr/sbin/rtty && chmod +x /usr/bin/rtty
	ln -sf $EXT_PLUGIN_CONFIG_DIR/vremote/bin/libssl.so.1.1 /usr/lib/libssl.so.1.1
	ln -sf $EXT_PLUGIN_CONFIG_DIR/vremote/bin/libcrypto.so.1.1 /usr/lib/libcrypto.so.1.1
	ln -sf $EXT_PLUGIN_CONFIG_DIR/vremote/bin/cert.pem /usr/ikuai/cert.pem         
	debug "rtty安装完成"
    return 0
}

exit_if_running

# 如果定时任务不存在，则添加定时任务
add_crontab

# 检查网络状态，直到网络连接成功才继续向下执行
check_network

debug "开始启动vremote....."

while true; do

    # 连接rtty服务
    connect_rtty_server

    # 推送状态数据
    push_stats_data

    # 同步共享账户
    lastShareSyncTime=$(cat $EXT_PLUGIN_CONFIG_DIR/vremote/lastShareSyncTime)
    [ -z "$lastShareSyncTime" ] && lastShareSyncTime="1970-01-01"
  
    if [ $(($(date +%s) - $(date -d "$lastShareSyncTime" +%s))) -gt 1800 ]; then
        debug "开始同步共享配置"
        sync_for_share_servermode
        sync_for_share_clientmode
        echo $(date +"%Y-%m-%d %H:%M") > $EXT_PLUGIN_CONFIG_DIR/vremote/lastShareSyncTime
        debug "共享配置同步完成"
    else
        debug "时间未到，跳过共享配置同步"
    fi

    sleep 300

done