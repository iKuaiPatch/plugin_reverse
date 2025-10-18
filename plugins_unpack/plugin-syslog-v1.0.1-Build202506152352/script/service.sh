#!/bin/bash /etc/ikcommon
PLUGIN_NAME="syslog"
script_path=$(readlink -f "$BASH_SOURCE")
plugin_dir=$(dirname "$script_path")

stop() {
    CONFIG_DB="/etc/mnt/ikuai/config.db" # 替换为你的数据库路径
    sqlite3 $CONFIG_DB "UPDATE syslog_server SET enabled='no';"
    # 重启服务
    killall iksyslogd
    iksyslogd
}

update_config() {
    sed -i '/save/!b;n;!b;n;/return 0/!i return 0' /usr/ikuai/script/send_log.sh
   
    # 检查必填参数是否已经传入
    if [ -z "$protocol" ] || [ -z "$port" ] || [ -z "$ip" ] || [ -z "$separator" ] || [ -z "$logs" ]; then
        echo "参数有误"
        return 1
    fi

    # protocol=$(echo "$protocol" | tr 'A-Z' 'a-z')

    # 打印调试信息
    
    # echo "protocol=$protocol" >>/tmp/syslogs.log
    # echo "port=$port" >>/tmp/syslogs.log
    # echo "ip=$ip" >>/tmp/syslogs.log
    # echo "separator=$separator" >>/tmp/syslogs.log
    # echo "logs=$logs" >>/tmp/syslogs.log

    # 将分隔符从 "n", "o", "r" 转换为实际的数值（例如 10, 15, 13）
    separator_value=10
    [ "$separator" = "n" ] && separator_value=10
    [ "$separator" = "r" ] && separator_value=13
    [ "$separator" = "o" ] && separator_value=15
    

    # 将 logs 字符串解析为每个日志类型的开启状态
    OPEN_IM=$(echo "$logs" | grep -q "open_im" && echo "1" || echo "0" )
    OPEN_PPPAUTH=$(echo "$logs" | grep -q "open_pppauth" && echo "1" || echo "0" )
    OPEN_IKTIMERD_AC=$(echo "$logs" | grep -q "open_iktimerd_ac" && echo "1" || echo "0" )
    OPEN_NAT=$(echo "$logs" | grep -q "open_nat" && echo "1" || echo "0")
    OPEN_OPT=$(echo "$logs" | grep -q "open_opt" && echo "1" || echo "0")
    OPEN_OFFLINE=$(echo "$logs" | grep -q "open_offline" && echo "1" || echo "0")
    OPEN_DDNS=$(echo "$logs" | grep -q "open_ddns" && echo "1" || echo "0")
    OPEN_DNS=$(echo "$logs" | grep -q "open_dns" && echo "1" || echo "0")
    OPEN_DHCP=$(echo "$logs" | grep -q "open_dhcp" && echo "1" || echo "0")
    OPEN_SYS=$(echo "$logs" | grep -q "open_sys" && echo "1" || echo "0")
    OPEN_PPPD=$(echo "$logs" | grep -q "open_pppd" && echo "1" || echo "0")
    OPEN_URL=$(echo "$logs" | grep -q "open_url" && echo "1" || echo "0")
    OPEN_ARP=$(echo "$logs" | grep -q "open_arp" && echo "1" || echo "0")

    # 打印调试信息
    echo "OPEN_IM=$OPEN_IM" >>/tmp/syslogs.log
    echo "OPEN_PPPAUTH=$OPEN_PPPAUTH" >>/tmp/syslogs.log
    echo "OPEN_IKTIMERD_AC=$OPEN_IKTIMERD_AC" >>/tmp/syslogs.log
    echo "OPEN_NAT=$OPEN_NAT" >>/tmp/syslogs.log
    echo "OPEN_OPT=$OPEN_OPT" >>/tmp/syslogs.log
    echo "OPEN_OFFLINE=$OPEN_OFFLINE" >>/tmp/syslogs.log
    echo "OPEN_DDNS=$OPEN_DDNS" >>/tmp/syslogs.log
    echo "OPEN_DNS=$OPEN_DNS" >>/tmp/syslogs.log
    echo "OPEN_DHCP=$OPEN_DHCP" >>/tmp/syslogs.log
    echo "OPEN_SYS=$OPEN_SYS" >>/tmp/syslogs.log
    echo "OPEN_PPPD=$OPEN_PPPD" >>/tmp/syslogs.log
    echo "OPEN_URL=$OPEN_URL" >>/tmp/syslogs.log
    echo "OPEN_ARP=$OPEN_ARP" >>/tmp/syslogs.log
    echo "separator_value=$separator_value" >>/tmp/syslogs.log

    logflagsum=$(($OPEN_IM+$OPEN_PPPAUTH+$OPEN_IKTIMERD_AC+$OPEN_NAT+$OPEN_OPT+$OPEN_OFFLINE+\
                    $OPEN_DDNS+$OPEN_DNS+$OPEN_DHCP+$OPEN_SYS+$OPEN_PPPD+$OPEN_URL+$OPEN_ARP))

    if [ $logflagsum -eq 13 ]; then
        open_all=1
    else
        open_all=0
    fi

    CONFIG_DB="/etc/mnt/ikuai/config.db" 
    sqlite3 "$CONFIG_DB" "UPDATE syslog_server SET host='', server='$ip', port=$port, \
                        protocol='$protocol', send_flag=1, open_all=$open_all, open_url=$OPEN_URL, \
                        open_im=$OPEN_IM, open_nat=$OPEN_NAT, open_iktimerd_ac=$OPEN_IKTIMERD_AC, \
                        open_pppauth=$OPEN_PPPAUTH, open_offline=$OPEN_OFFLINE, open_dhcp=$OPEN_DHCP, \
                        open_arp=$OPEN_ARP, open_pppd=$OPEN_PPPD, open_ddns=$OPEN_DDNS, open_opt=$OPEN_OPT, \
                        open_sys=$OPEN_SYS, open_dns=$OPEN_DNS, expired=0, delimiter=$separator_value WHERE id=1;"

    enabled=$(sqlite3 "$CONFIG_DB" "select enabled from syslog_server WHERE id=1;")

    if [ "$enabled" = "yes" ]; then
        [ "$OPEN_DNS" = "1" ] && ik_cntl dns_log enable
        [ "$OPEN_DNS" = "0" ] && ik_cntl dns_log disable
        /usr/ikuai/script/audit.sh save open_im_record=$OPEN_IM open_url_record=$OPEN_URL open_terminal_record=0
        killall iksyslogd
        iksyslogd
    fi
}

set_log_enable(){

    echo "$enable" >>/tmp/logsysd.log

    CONFIG_DB="/etc/mnt/ikuai/config.db" 
    sqlite3 "$CONFIG_DB" "UPDATE syslog_server SET enabled='$enable' WHERE id=1;"

    result=$(sqlite3 "$CONFIG_DB" "select open_dns,open_url,open_im from syslog_server WHERE id=1;")
    IFS='|' read -r opendns openurl openim <<<"$result"

    if [ "$enable" = "yes" ]; then
        [ "$opendns" = "1" ] && ik_cntl dns_log enable
        [ "$opendns" = "0" ] && ik_cntl dns_log disable
        /usr/ikuai/script/audit.sh save open_im_record=$openim open_url_record=$openurl open_terminal_record=0

    else
        ik_cntl dns_log disable
        /usr/ikuai/script/audit.sh save open_im_record=0 open_url_record=0 open_terminal_record=0
    fi

    killall iksyslogd
    iksyslogd
}

show() {
    Show __json_result__
}

__show_data() {

    # echo "status" >>/tmp/logsys.log
    configdb="/etc/mnt/ikuai/config.db" # 替换为你的数据库路径
    data=$(sqlite3 "$configdb" "SELECT * FROM syslog_server WHERE id=1;")
    IFS='|' read -r -a values <<<"$data"

    # 从查询的值数组中获取字段
    id="${values[0]}"                # id 字段
    enabled="${values[1]}"           # enabled 字段
    host="${values[2]}"              # host 字段
    server="${values[3]}"            # server 字段
    port="${values[4]}"              # port 字段
    protocol="${values[5]}"          # protocol 字段
    send_flag="${values[6]}"         # send_flag 字段
    open_all="${values[7]}"          # open_all 字段
    open_url="${values[8]}"          # open_url 字段
    open_im="${values[9]}"           # open_im 字段
    open_nat="${values[10]}"         # open_nat 字段
    open_iktimerd_ac="${values[11]}" # open_iktimerd_ac 字段
    open_pppauth="${values[12]}"     # open_pppauth 字段
    open_offline="${values[13]}"     # open_offline 字段
    open_dhcp="${values[14]}"        # open_dhcp 字段
    open_arp="${values[15]}"         # open_arp 字段
    open_pppd="${values[16]}"        # open_pppd 字段
    open_ddns="${values[17]}"        # open_ddns 字段
    open_opt="${values[18]}"         # open_opt 字段
    open_sys="${values[19]}"         # open_sys 字段
    open_dns="${values[20]}"         # open_dns 字段
    expired="${values[21]}"          # expired 字段
    delimiter="${values[22]}"        # delimiter 字段

    # echo "$enabled" >>/tmp/syslog.log

    # 使用 json_append 构建 JSON 返回
    json_append __json_result__ id:int
    json_append __json_result__ enabled:str
    json_append __json_result__ host:str
    json_append __json_result__ server:str
    json_append __json_result__ port:str
    json_append __json_result__ protocol:str
    json_append __json_result__ send_flag:int
    json_append __json_result__ open_all:int
    json_append __json_result__ open_url:int
    json_append __json_result__ open_im:int
    json_append __json_result__ open_nat:int
    json_append __json_result__ open_iktimerd_ac:int
    json_append __json_result__ open_pppauth:int
    json_append __json_result__ open_offline:int
    json_append __json_result__ open_dhcp:int
    json_append __json_result__ open_arp:int
    json_append __json_result__ open_pppd:int
    json_append __json_result__ open_ddns:int
    json_append __json_result__ open_opt:int
    json_append __json_result__ open_sys:int
    json_append __json_result__ open_dns:int
    json_append __json_result__ expired:int
    json_append __json_result__ delimiter:int
}
