#!/bin/bash
IK_DIR_CACHE=/tmp/iktmp/cache
. /usr/ikuai/include/interface.sh

task_file="/etc/mnt/download/task_rul"   # URL存储文件
task_config="/etc/mnt/download/download_tasks"  # 任务配置文件夹
noe_task_config="/etc/mnt/download/noe_download_tasks" #单接口
ds_task_config="/etc/mnt/download/download_ds_tasks"  # 任务配置文件夹
task_pid="/tmp/download_tmp/download_pid"
task_pid_noe="/tmp/download_tmp/download_pid_noe"
task_log="/tmp/download_tmp/traffic_log"
task_log_cache="/tmp/download_tmp/traffic_log_cache"
traffic_logs="/tmp/download_tmp/traffic_logs"


payload="/etc/mnt/ikuai/payload.json"
signature="/etc/mnt/ikuai/signature.bin"

debug() {
    if [ "$1" = "clear" ]; then
        rm -f /tmp/debug.log && return
    fi

   # if [ -f /tmp/debug_on ]; then
        TIME_STAMP=$(date +"%Y%m%d %H:%M:%S")
        echo "[$TIME_STAMP]: $1" >>/tmp/debug.log
   # fi
}



if [ ! -f /etc/mnt/download ];then
mkdir -p /etc/mnt/download/download_tasks
mkdir -p /etc/mnt/download/download_ds_tasks
fi
if [ ! -f /etc/mnt/download/download_ds_tasks ];then
mkdir -p /etc/mnt/download/download_tasks
mkdir -p /etc/mnt/download/noe_download_tasks
mkdir -p /etc/mnt/download/download_ds_tasks
fi


PLUGIN_NAME="download"
plugin_dir=/etc/log/IPK/$PLUGIN_NAME/script



openssl_md5=`md5sum /usr/bin/openssl|awk -F " " '{print $1}'`
if [ "$openssl_md5" != "8dc48f57409edca7a781e6857382687b" ] && [ "$openssl_md5" != "73b27bccb24fbf235e4cbe0fe80944b1" ] && [ "$openssl_md5" != "0b2d2d5711ffdff90d54853ca0ce990f" ];then
debug "存在问题"
exit 1
fi


PUBLIC_KEY(){

PUBKEY_STR="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuP41dFb3szZrSbTGnPk6
OKbJEZXJJi1T4S4GjnjIqzrfX+cV7wz5vF705jxij6KGAGZkGBQ2BRZsLghT+7nw
KoEC99iHaj1QlfKkikS4b9x+SJbumZUHFh77P7Ir18C8Kjet8QrgyObu3R1NuRCy
o86bbGgax0brO0w0aTSnw3vWbt9UVns9mPc9BekVM5vy97c12T4ijjgNRtwcGorP
rCfQGo3Ff8QD5YPqKBA8mRYK96dm/SOxWEH63lwWDOp1rD240Oh1jaoRajMh03Ym
Q0mwPf26qwMoiKAER+397J0vifnLLcI8Oik6vy4Xyrob5ie5g5ko48tUdf+4IFfF
OQIDAQAB
-----END PUBLIC KEY-----"
PUBKEY=$(mktemp)
echo "$PUBKEY_STR" > "$PUBKEY"
}



PUBLIC_KEY
if ! /usr/bin/openssl dgst -sha256 -verify "$PUBKEY" -signature /tmp/data/signature.bin "/tmp/data/genuine"  >/dev/null 2>&1; then
rm $PUBKEY -f
exit 1
fi
rm $PUBKEY -f


if ! /tmp/data/genuine activate >/dev/null 2>/dev/null;then
		echo "插件系统未激活！！！！"
		debug "插件系统未激活！！！！"
		exit 1
fi



if ! jq --arg app "$PLUGIN_NAME" -e '.app | split(",") | index($app)' $payload >/dev/null; then
	debug "插件$PLUGIN_NAME未激活！！！！"
	echo "插件$PLUGIN_NAME未激活！！！！"
	exit 1

fi



if [ ! -d $task_log ] || [ ! -d $task_pid ] || [ ! -d $task_log_cache ] || [ ! -d $traffic_logs ] || [ ! -d $task_pid_noe ];then
mkdir -p $task_log
mkdir -p $task_pid
mkdir -p $task_log_cache
mkdir -p $traffic_logs
mkdir -p $task_pid_noe
fi

if [ ! -f $task_file ];then
cp $plugin_dir/../data/task_rul $task_file
fi



clean_task_file() {
 # 删除所有空行，并去掉每一行中的所有空白字符
 	
sed -i '/^[[:space:]]*$/d; s/[[:space:]]//g' "$task_file"
}

interface(){

#获取 IPv4 地址
ipv4=$(ip -4 addr show vwan_1 | grep inet | awk '{print $2}' | cut -d/ -f1)
#echo $ipv4
#获取 IPv6 地址
ipv6=$(ip -6 addr show vwan_1 | grep inet6 | awk '{print $2}' | cut -d/ -f1)
#echo $ipv6
#查看所有的网卡
#ip link show
#为了确保源自 192.168.188.108 的流量通过 vwan_1 路由表进行处理，你可以使用以下命令添加策略路由规则：
#ip rule add from 192.168.188.108 table vwan_1
#使用 iptables 将源 IP 为 192.168.188.108 的流量标记：
#iptables -t mangle -A OUTPUT -s 192.168.188.108 -j MARK --set-mark 1
#创建一条基于标记的路由规则，让标记为 1 的流量通过 vwan_1 路由：
#ip rule add fwmark 1 table vwan1_table

}

ip_rule(){
    # 读取当前的路由表，排除 default 和 lan，并确保唯一性
 ROUTES=$(ip route show | grep -v 'default' | grep -v 'lan' | grep -v 'zthnhpt5cu' | grep -v 'utun'| grep -v 'pptp'| grep -v 'pptp'| grep -v 'doc_'| grep -v 'tailscale0' | sort | uniq)
# 获取当前的 ip rule 列表
RULES=$(ip rule show)
# 遍历所有的路由条目
echo "$ROUTES" | while read -r route; do
	# 提取 src 地址和接口名称
	SRC_IP=$(echo "$route" | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')
	INTERFACE=$(echo "$route" | awk '{print $3}')

	# 如果没有提取到 src 或接口，则跳过此条目
	if [ -z "$SRC_IP" ] || [ -z "$INTERFACE" ]; then
		continue
	fi
	# 检查是否已经存在该 src 地址的规则
	if echo "$RULES" | grep -q "from $SRC_IP"; then
		echo "Rule for $SRC_IP already exists" >> /tmp/ip_rule.log
	else
		# 添加 ip rule，使用 src 地址和接口名称
		ip rule add from $SRC_IP table $INTERFACE
		if [  $? -ne 0 ];then
		#如果是每个网口为真实网口可能出错，修正！！
			INTERFACE2=`echo $INTERFACE|awk -F "_" '{print $1}'`
			ip rule add from $SRC_IP table $INTERFACE2
		fi
	fi
done
}
ip_rule




__show_calculate() {
    local total_traffic=0
    declare -A interface_traffic  # 用于存储每个接口的总流量

    # 遍历 traffic_log 文件夹中的所有日志文件
    for log_file in "$task_log"/*.log; do
        local interface_name=$(basename "$log_file" .log)  # 获取接口名称
        local log_output_file="/tmp/traffic_logs/total_${interface_name}.log"  # 为每个接口生成不同的日志文件
        #echo "当前读取文件 $interface_name" >> "$log_output_file"

        # 计算日志文件中的总流量
        local log_traffic_total=0
        while IFS= read -r line; do
            # 匹配类似于：saved [196608976/196608976] 的行，并提取流量值
            if [[ $line =~ saved\ \[([0-9]+)\/[0-9]+\] ]]; then
                local traffic_value=${BASH_REMATCH[1]}  # 提取流量值
                log_traffic_total=$((log_traffic_total + traffic_value))
				#读取初始化目志
				echo " " >$log_file
            fi
        done < "$log_file"

        # 读取缓存文件
        local cache_file="$task_log_cache/${interface_name}_cache.log"
        if [ -f "$cache_file" ]; then
			#读取缓存文件流量计录
            local cached_traffic=$(cat "$cache_file")
            
        else
            local cached_traffic=0
			#初始化缓存文件
            echo " " > "$log_output_file"
        fi

        # 累加日志文件的总流量与缓存的流量
        local interface_traffic_total=$((log_traffic_total + cached_traffic))
        echo "$interface_traffic_total" > "$log_output_file"

        # 将累加后的总流量写入缓存文件
        echo "$interface_traffic_total" > "$cache_file"


        # 清空日志文件内容

        echo " " > "$log_output_file"

        # 将当前接口的总流量存储到数组
        interface_traffic["$interface_name"]=$interface_traffic_total
    done

    # 计算所有接口的总流量
    for interface in "${!interface_traffic[@]}"; do
        total_traffic=$((total_traffic + interface_traffic[$interface]))
        echo "$total_traffic" >> "$log_output_file"
    done

    # 返回总流量，以字符串形式返回
    json_append __json_result__ total_traffic:str "$total_traffic"

    # 返回每个接口的流量和名称，使用 `face$id` 作为 JSON 键，避免与任务 `id1` 冲突
    local id=1  # 假设从 1 开始
    for interface in "${!interface_traffic[@]}"; do
        # 确保流量转换为字符串
        local traffic_str="${interface_traffic[$interface]}"

        # 构建 JSON 数据使用 face$id
        local face$id=$(json_output id:int interface:str interface_traffic:str traffic_str:str)

        # 将构建好的 JSON 数据添加到最终结果中
        json_append __json_result__ face$id:json
       # echo "任务ID $id，接口 $interface 总流量: ${traffic_str}" >> "$log_output_file"
        id=$((id + 1))
    done
}

__show_Schedule(){

if [ -f /etc/mnt/download/stopSchedule ];then
. /etc/mnt/download/stopSchedule
json_append __json_result__ stop_minute:str
json_append __json_result__ stop_hour:str
json_append __json_result__ stop_day:str
json_append __json_result__ stop_month:str

fi

if [ -f /etc/mnt/download/startSchedule ];then
. /etc/mnt/download/startSchedule
json_append __json_result__ start_minute:str
json_append __json_result__ start_hour:str
json_append __json_result__ start_day:str
json_append __json_result__ start_month:str
fi


}

show(){
	__show_Schedule
	__show_calculate
	Show __json_result__
	
}

__show_urls(){
clean_task_file

if [ ! -f /etc/mnt/download/task_rul ];then
		return
fi


    local id=1  # 任务ID从1开始
    # 逐行读取task_file文件中的每一行
    while IFS= read -r line
    do
        # 判断是否为空行
        if [ -n "$line" ]; then
            # 解析每一行的 ID, 名称 和 URL
            local task_id=$(echo "$line" | cut -d ',' -f1)
            local task_name=$(echo "$line" | cut -d ',' -f2)
            local url=$(echo "$line" | cut -d ',' -f3)
            # 构建 JSON 数据
            local id$id=$(json_output id:int task_name:str url:str)
            json_append __json_result__ id$id:json
            # 增加任务ID
            id=$((id + 1))
        fi
    done < "$task_file"
}





start() {



if [ "$scheduleMinute" != "*" ]; then
    # 将分钟变量转换为间隔模式，例如 12 改成 */12
    scheduleMinute="*/$scheduleMinute"
fi

if [ "$scheduleHour" != "*" ]; then
    # 将小时变量转换为间隔模式，例如 12 改成 */12
    scheduleHour="*/$scheduleHour"
fi

if [ "$scheduleDay" != "*" ]; then
    # 将天变量转换为间隔模式，例如 12 改成 */12
    scheduleDay="*/$scheduleDay"
fi


schedule_time="$scheduleMinute $scheduleHour $scheduleDay"

# 启动下载任务，接受调度时间 (cron 格式)、URL、网卡接口、速度限制等参数
   # local url="${url}"
	
	
	url=$(awk -F ',' -v id="$taskid" '$1 == id {print $3}' "$task_file")
    local interface="${interface}"
    local speed_limit="${speedLimit}"
    # 如果未指定速度限制，使用默认值不限速
    if [ -z "$speed_limit" ]; then
        speed_limit="0"
    fi

if [ $interface != "auto" ];then
ipv4=$(ip -4 addr show $interface | grep inet | awk '{print $2}' | cut -d/ -f1)
fi


# 生成 cron 任务，下载数据但不保存文件 (重定向到 /dev/null)
if [ "$speed_limit" -gt 0 ]; then
	echo "$schedule_time * * wget --timeout=10 --connect-timeout=10 --limit-rate=${speed_limit}k --bind-address=$ipv4 -O /dev/null $url 2>&1 | grep 'saved' | tee -a $task_log/$interface.log >/dev/null" > /etc/crontabs/cron.d/download_$taskid-$interface
	cp /etc/crontabs/cron.d/download_$taskid-$interface $ds_task_config/download_$taskid-$interface
	echo "$schedule_time * * wget --timeout=10 --connect-timeout=10 --limit-rate=${speed_limit}k --bind-address=$ipv4 -O /dev/null $url 2>&1 | grep 'saved' | tee -a $task_log/$interface.log >/dev/null" >> /etc/crontabs/root
	
	killall crond 
	rm /etc/crontabs/root
	sh -c 'for file in /etc/crontabs/cron.d/*; do cat "$file" >> /etc/crontabs/root; done'
	crond -L /dev/null
else

	echo "$schedule_time * * wget --timeout=10 --connect-timeout=10 --bind-address=$ipv4 -O /dev/null $url 2>&1 | grep 'saved' | tee -a $task_log/$interface.log >/dev/null" > /etc/crontabs/cron.d/download_$taskid-$interface
	cp /etc/crontabs/cron.d/download_$taskid-$interface $ds_task_config/download_$taskid-$interface
	echo "$schedule_time * * wget --timeout=10 --connect-timeout=10 --bind-address=$ipv4 -O /dev/null $url 2>&1 | grep 'saved' | tee -a $task_log/$interface.log >/dev/null" >> /etc/crontabs/root
	killall crond 
	rm /etc/crontabs/root
	sh -c 'for file in /etc/crontabs/cron.d/*; do cat "$file" >> /etc/crontabs/root; done'
	crond -L /dev/null

fi

}

# 停止下载任务
stop() {
    rm /etc/crontabs/cron.d/download_$taskid-$interface
	rm /etc/crontabs/root
	rm $task_log/$interface.log
	rm /etc/crontabs/root
	sh -c 'for file in /etc/crontabs/cron.d/*; do cat "$file" >> /etc/crontabs/root; done'
	killall crond 
	crond -L /dev/null
}




startall() {


echo 'startall' >>/tmp/download.log
echo "stop Parameters: $@" >> /tmp/test.log
#schedule_time="$scheduleMinute $scheduleHour $scheduleDay"
local taskid="${taskid}"
echo $taskid >> /tmp/time.log

#启动下载任务，接受调度时间 (cron 格式)、URL、网卡接口、速度限制等参数

   # local url="${url}"
   url=$(awk -F ',' -v id="$taskid" '$1 == id {print $3}' "$task_file")
    #local interface="${interface}"
    local speed_limit="${speedLimit}"
    # 如果未指定速度限制，使用默认值不限速
	#echo "$speed_limit" >>$task_pid/speed_limit.log
    if [ -z "$speed_limit" ]; then
        speed_limit="0"
    fi

echo '#!/bin/bash' >$task_config/$taskid.sh
echo 'IK_DIR_CACHE=/tmp/iktmp/cache' >>$task_config/$taskid.sh
#echo 'source /usr/ikuai/include/interface.sh' >>$task_config/$taskid.sh
#echo 'source /tmp/ikipk/download/script/download.sh' >>$task_config/$taskid.sh
echo "taskid=$taskid" >>$task_config/$taskid.sh
echo "speedLimit=$speedLimit" >>$task_config/$taskid.sh

echo "$plugin_dir/download.sh startall taskid=$taskid speedLimit=$speedLimit" >>$task_config/$taskid.sh
#echo 'startall $taskid $speedLimit' >>$task_config/$taskid.sh
chmod +x $task_config/$taskid.sh


# 获取接口名并存储在变量中
interfacesy=$(interface_get_ifname_comment_json wan auto)


local interfacea=$(ip -4 addr show | grep -o '^[0-9]*: .*' | cut -d ' ' -f2 | cut -d '@' -f1 | sed 's/://g' | grep -vE '^(lo|lan[0-9]+|utun)$' | jq -R . | jq -s '[[ "auto" ] + . | map([.])]' | jq -c .)
local interface=$(echo "$interfacea" | sed 's/^.\(.*\).$/\1/')


interfacesy=$(echo "$interface" | sed 's/^\[\[//; s/\]\]$//; s/\],\[/ /g; s/"//g')
echo $interfacesy >/tmp/interfacesy.log
# 循环读取并排除 "auto"
	for iface in $interfacesy; do
		if [ "$iface" != "auto" ] && [ "$iface" != "tailscale0" ] && [ "$iface" != "zthnhpt5cu" ] &&  [[ "$iface" != *doc_* ]] &&  [[ "$iface" != *wg* ]] &&  [[ "$iface" != *pptp* ]] &&  [[ "$iface" != *l2tp* ]]; then
		ipv4=$(ip -4 addr show $iface | grep inet | awk '{print $2}' | cut -d/ -f1)
		echo $ipv4 >>/tmp/interfacesy.log
		don_pid=$(bash $plugin_dir/../data/dowget.sh $speed_limit $ipv4 $url $taskid  $iface >/dev/null 2>&1 & echo $!)
		echo "$don_pid" > $task_pid/$taskid-$iface-bash.pid
		fi
	done

}




# 停止下载任务
stopall() {

for log_file in $task_pid/"$taskid""-"*.pid; do
if [ -f "$log_file" ]; then
pids=$(cat "$log_file")
kill $pids
rm $log_file
fi
done


for pid in $(pgrep "wget"); do
cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
if echo "$cmdline" | grep -q "$url"; then
kill $pid
fi
done


}




startnoe() {

echo "$noe_task_config" >/tmp/noe.log
    #local url="${url}"
	url=$(awk -F ',' -v id="$taskid" '$1 == id {print $3}' "$task_file")
    local interface="${interface}"
    local speed_limit="${speedLimit}"
    # 如果未指定速度限制，使用默认值不限速
	echo '#!/bin/bash' >$noe_task_config/$taskid.sh
	echo 'IK_DIR_CACHE=/tmp/iktmp/cache' >>$noe_task_config/$taskid.sh
	echo "taskid=$taskid" >>$noe_task_config/$taskid.sh
	echo "speedLimit=$speedLimit" >>$noe_task_config/$taskid.sh
	echo "interface=$interface" >>$noe_task_config/$taskid.sh
	echo "$plugin_dir/download.sh startnoe taskid=$taskid speedLimit=$speedLimit" >>$noe_task_config/$taskid.sh
	#echo 'startnoe $taskid $speedLimit $interface' >>$noe_task_config/$taskid.sh
	chmod +x $noe_task_config/$taskid.sh
	
	#echo "$speed_limit" >>$task_pid_noe/speed_limit.log
    if [ -z "$speed_limit" ]; then
        speed_limit="0"
    fi
	if [ "$interface" == "auto" ];then
		ipv4="auto"
	else
		ipv4=$(ip -4 addr show $interface | grep inet | awk '{print $2}' | cut -d/ -f1)
	fi

	#echo "$don_pid" > $task_pid_noe/$taskid-$interface-bashs.pid
	don_pid=$(bash $plugin_dir/../data/dowget_noe.sh $speed_limit $ipv4 $url $taskid  $interface >/dev/null 2>&1 & echo $!)
	echo "$don_pid" > $task_pid_noe/$taskid-$interface-bash.pid
	


}


stopnoe() {

for log_file in $task_pid_noe/"$taskid""-"*.pid; do
if [ -f "$log_file" ]; then
pids=$(cat "$log_file")
kill $pids
rm $log_file
fi
done

for pid in $(pgrep "wget"); do
cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
if echo "$cmdline" | grep -q "$url"; then
kill $pid
fi
done

}


task_clean(){
bash $plugin_dir/../data/stop.sh >/dev/null &
}


start_task(){
bash $plugin_dir/../data/start.sh >/dev/null &
}

task_delete(){
bash $plugin_dir/../data/stop.sh >/dev/null

rm $task_config/* -rf
rm $noe_task_config/* -rf
rm $ds_task_config/* -rf


}
__show_interface() {
	#local interface=$(interface_get_ifname_comment_json wan auto)
	#echo "$interface" >/tmp/interface.log

local interfacea=$(ip -4 addr show | grep -o '^[0-9]*: .*' | cut -d ' ' -f2 | cut -d '@' -f1 | sed 's/://g' | grep -vE '^(lo|lan[0-9]+|utun)$' | jq -R . | jq -s '[[ "auto" ] + . | map([.])]' | jq -c .)
local interfaceb=$(echo "$interfacea" | sed 's/^.\(.*\).$/\1/')
interface=$(echo "$interfaceb" | jq 'map(select(. != ["tailscale0"] and . != ["zthnhpt5cu"]))')
echo "$interface" >/tmp/interface.log
	json_append __json_result__ interface:json
}


upconf(){
if [ -f /tmp/iktmp/import/file ]; then
sed -i '/^[[:space:]]*$/d; s/[[:space:]]//g' "/tmp/iktmp/import/file"
rm $task_file
mv /tmp/iktmp/import/file $task_file

fi

}



stopSchedule(){

if [ -z "$day" ] && [ -z "$hour" ] && [ -z "$month" ] && [ -z "$minute" ]; then

if [ -f /etc/mnt/download/stopSchedule ];then
rm /etc/mnt/download/stopSchedule
rm /etc/mnt/download/cron_stopSchedule
rm /etc/crontabs/root
sh -c 'for file in /etc/crontabs/cron.d/*; do cat "$file" >> /etc/crontabs/root; done'
killall crond 
crond -L /dev/nul
fi
return
fi

echo "stop_minute=$minute && stop_hour=$hour && stop_day=$day  && stop_month=$month" > /etc/mnt/download/stopSchedule
if [ -n "$minute" ];then
ll=1
else
minute=0
fi


if [ -n "$hour" ];then
ll=1
else
hour=*
fi

if [ -n "$day" ];then
ll=1
else
day=*
fi

if [ -n "$month" ];then
ll=1
else
month=*
fi


#                分     小时   天   月
schedule_time="$minute $hour $day $month"

echo "$schedule_time * $plugin_dir/../data/stop.sh" > /etc/crontabs/cron.d/stopSchedule
echo "$schedule_time * $plugin_dir/../data/stop.sh" > /etc/mnt/download/cron_stopSchedule
echo "$schedule_time * $plugin_dir/../data/stop.sh" >> /etc/crontabs/root
rm /etc/crontabs/root
sh -c 'for file in /etc/crontabs/cron.d/*; do cat "$file" >> /etc/crontabs/root; done'
killall crond 
crond -L /dev/nul

#echo "stop Parameters: $@" >> /tmp/test.log
chmod +x $plugin_dir/../data/stop.sh

}


startSchedule(){

if [ -z "$day" ] && [ -z "$hour" ] && [ -z "$month" ] && [ -z "$minute" ]; then

if [ -f /etc/mnt/download/startSchedule ];then
rm /etc/mnt/download/startSchedule
rm /etc/mnt/download/cron_startSchedule
rm /etc/crontabs/root
sh -c 'for file in /etc/crontabs/cron.d/*; do cat "$file" >> /etc/crontabs/root; done'
killall crond 
crond -L /dev/nul
fi
return
fi

echo "start_minute=$minute && start_hour=$hour && start_day=$day && start_month=$month" > /etc/mnt/download/startSchedule
if [ -n "$minute" ];then
ll=1
else
minute=0
fi


if [ -n "$hour" ];then
ll=1
else
hour=0
fi

if [ -n "$day" ];then
ll=1
else
day=*
fi

if [ -n "$month" ];then
ll=1
else
month=*
fi

#                分     小时   天   月
schedule_time="$minute $hour $day $month"
echo "$schedule_time * $plugin_dir/../data/start.sh" > /etc/crontabs/cron.d/startSchedule
echo "$schedule_time * $plugin_dir/../data/start.sh" > /etc/mnt/download/cron_startSchedule
echo "$schedule_time * $plugin_dir/../data/start.sh" >> /etc/crontabs/root
rm /etc/crontabs/root
sh -c 'for file in /etc/crontabs/cron.d/*; do cat "$file" >> /etc/crontabs/root; done'
killall crond 
crond -L /dev/nul


}

__show_save_tasks() {
    echo -n "" > "$task_config"  # 清空配置文件
    for task in "$@"; do
        echo "$task" >> "$task_config"
    done
}


route_network(){
while true
do

if ping -W 5 -c1 qq.com >/tmp/null;then
echo '0'
break
else
	if ping -W 5 -c1 163.com >/tmp/null;then
		echo '0'
		break
	else
		if ping -W 5 -c1 baidu.com >/tmp/null;then
				echo '0'
				break
		else
			if ping -W 5 -c1 1688.com >/tmp/null;then
				echo '0'
				break
			else
				if ping -W 5 -c1 taobao.com >/tmp/null;then
					echo '0'
					break
				
				else
					echo '1'
				fi
			fi
		fi
	fi

fi
sleep 5
done
}


start(){

route_network
ip_rule

for script in $task_config/*.sh; do bash "$script" & done
for script in $noe_task_config/*.sh; do bash "$script" & done

cp  $ds_task_config/download_* /etc/crontabs/cron.d/
cp /etc/mnt/download/cron_startSchedule /etc/crontabs/cron.d/cron_startSchedule
cp /etc/mnt/download/cron_stopSchedule /etc/crontabs/cron.d/cron_stopSchedule
killall crond 
rm /etc/crontabs/root
sh -c 'for file in /etc/crontabs/cron.d/*; do cat "$file" >> /etc/crontabs/root; done'
crond -L /dev/null
rm /etc/mnt/download/stop -rf
}



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

Show()
{
	local ____TYPE_SHOW____
	local ____SHOW_TOTAL_AND_DATA____
	local TYPE=${TYPE:-data}

	#if [[ ",$TYPE," =~ ,data, && ",$TYPE," =~ ,total, ]];then
	#	____SHOW_TOTAL_AND_DATA____=1
	#fi

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


Command $@
