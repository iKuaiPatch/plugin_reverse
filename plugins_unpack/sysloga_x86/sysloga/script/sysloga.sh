#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "$BASH_SOURCE")
plugin_dir=$(dirname "$script_path")

stop(){
CONFIG_DB="/etc/mnt/ikuai/config.db"  # 替换为你的数据库路径
sqlite3 $CONFIG_DB "UPDATE syslog_server SET enabled='no';"
# 重启服务
killall iksyslogd
iksyslogd
}

update_config(){
sed -i '/save/!b;n;!b;n;/return 0/!i return 0' /usr/ikuai/script/send_log.sh
# 数据库文件路径
CONFIG_DB="/etc/mnt/ikuai/config.db"  # 替换为你的数据库路径

# 初始化所有参数变量
protocol=""
port=""
ip=""
separator=""
logs=""
send_flag=1  # 默认值为1

# 解析传入的参数
for param in "$@"
do
    case $param in
        protocol=*)
            protocol="${param#*=}"
            ;;
        port=*)
            port="${param#*=}"
            ;;
        ip=*)
            ip="${param#*=}"
            ;;
        separator=*)
            separator="${param#*=}"
            ;;
        logs=*)
            logs="${param#*=}"
            ;;
    esac
done

# 检查必填参数是否已经传入
if [ -z "$protocol" ] || [ -z "$port" ] || [ -z "$ip" ] || [ -z "$separator" ] || [ -z "$logs" ]; then
    echo "参数有误" >>/tmp/syslogs.log
    exit 1
fi
send_flag=1
# 打印调试信息

protocol=$(echo "$protocol" | tr 'A-Z' 'a-z')

echo "protocol=$protocol" >>/tmp/syslogs.log
echo "port=$port" >>/tmp/syslogs.log
echo "ip=$ip" >>/tmp/syslogs.log
echo "separator=$separator" >>/tmp/syslogs.log
echo "logs=$logs" >>/tmp/syslogs.log




# 将分隔符从 "n", "o", "r" 转换为实际的数值（例如 10, 15, 13）
case "$separator" in
    "n")
        separator_value=10
        ;;
    "o")
        separator_value=15
        ;;
    "r")
        separator_value=13
        ;;
    *)
        separator_value=10  # 默认值
        ;;
esac

# 将 logs 字符串解析为每个日志类型的开启状态
OPEN_IM=$(echo "$logs" | cut -c1)
OPEN_PPPAUTH=$(echo "$logs" | cut -c2)
OPEN_IKTIMERD_AC=$(echo "$logs" | cut -c3)
OPEN_NAT=$(echo "$logs" | cut -c4)
OPEN_OPT=$(echo "$logs" | cut -c5)
OPEN_OFFLINE=$(echo "$logs" | cut -c6)
OPEN_DDNS=$(echo "$logs" | cut -c7)
OPEN_DNS=$(echo "$logs" | cut -c8)
OPEN_DHCP=$(echo "$logs" | cut -c9)
OPEN_SYS=$(echo "$logs" | cut -c10)
OPEN_PPPD=$(echo "$logs" | cut -c11)
OPEN_URL=$(echo "$logs" | cut -c12)
OPEN_ARP=$(echo "$logs" | cut -c13)

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
#到期expired值改为0
expired=0
if [ "$open_dns" = "1" ];then
	ik_cntl dns_log enable
else
	ik_cntl dns_log disable
fi

if [ "$logs" == "1111111111111" ];then
open_all=1
else
open_all=0
fi

sqlite3 "$CONFIG_DB" "UPDATE syslog_server SET enabled='yes', host='', server='$ip', port=$port, protocol='$protocol', send_flag=$send_flag, open_all=$open_all, open_url=$OPEN_URL, open_im=$OPEN_IM, open_nat=$OPEN_NAT, open_iktimerd_ac=$OPEN_IKTIMERD_AC, open_pppauth=$OPEN_PPPAUTH, open_offline=$OPEN_OFFLINE, open_dhcp=$OPEN_DHCP, open_arp=$OPEN_ARP, open_pppd=$OPEN_PPPD, open_ddns=$OPEN_DDNS, open_opt=$OPEN_OPT, open_sys=$OPEN_SYS, open_dns=$OPEN_DNS, expired=0, delimiter=$separator_value WHERE id=1;"

# 重启服务
killall iksyslogd
iksyslogd


}


show(){
    Show __json_result__
}

__show_status(){

echo "status" >>/tmp/logsys.log
# 假设 $configdb 是你的数据库路径
configdb="/etc/mnt/ikuai/config.db"  # 替换为你的数据库路径

# 查询数据
data=$(sqlite3 "$configdb" "SELECT * FROM syslog_server WHERE id=1;")

# 将数据按分隔符分割为数组
IFS='|' read -r -a values <<< "$data"

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

echo "$enabled" >>/tmp/syslog.log

# 使用 json_append 构建 JSON 返回
json_append __json_result__ id:int
json_append __json_result__ enabled:str
json_append __json_result__ host:str
json_append __json_result__ server:str
json_append __json_result__ port:int
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
