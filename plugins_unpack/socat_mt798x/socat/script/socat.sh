#!/bin/bash /etc/ikcommon 

start(){

    if [ -f /etc/mnt/socat.conf ];then
		bash /etc/mnt/socat.conf >/dev/null &
    fi
}

stop(){

    killall socat >/dev/null
}

show(){
Show __json_result__
}

__show_status(){

local status=0

if killall -q -0 socat ;then
	local status=1
fi

json_append __json_result__ status:int

}



add_config(){
rm /tmp/socat.log
# 调试：输出传递的参数
echo "All Parameters: $@" >> /tmp/socat.log

# 提取每个参数的值
for param in "$@"
do
    case $param in
        protocol=*)
            protocol="${param#*=}"
            ;;
        externalPort=*)
            externalPort="${param#*=}"
            ;;
        internalAddress=*)
            internalAddress="${param#*=}"
            ;;
        internalPort=*)
            internalPort="${param#*=}"
            ;;
    esac
done

# 输出变量的值到日志文件
#echo "Protocol: $protocol" >> /tmp/socat.log
#echo "External Port: $externalPort" >> /tmp/socat.log
#echo "Internal Address: $internalAddress" >> /tmp/socat.log
#echo "Internal Port: $internalPort" >> /tmp/socat.log
						  
#socat TCP6-LISTEN:8085,fork,reuseaddr TCP4:192.168.188.101:8081 &
#socat TCP6-LISTEN:8081,fork,reuseaddr TCP4:192.168.188.101:8081

if [ $protocol == "TCP" ];then
echo "socat TCP6-LISTEN:$externalPort,fork,reuseaddr TCP4:$internalAddress:$internalPort >/dev/null &" >> /etc/mnt/socat.conf
socat TCP6-LISTEN:$externalPort,fork,reuseaddr TCP4:$internalAddress:$internalPort >/dev/null &
fi

if [ $protocol == "UDP" ];then
echo "socat UDP6-LISTEN:$externalPort,fork,reuseaddr UDP4:$internalAddress:$internalPort >/dev/null &" >> /etc/mnt/socat.conf
socat UDP6-LISTEN:$externalPort,fork,reuseaddr UDP4:$internalAddress:$internalPort >/dev/null &
fi


	
}

__show_configs() {
    id=1
    # 逐行读取配置文件
    while IFS= read -r line
    do
        # 判断该行是否包含 'TCP6-LISTEN'
			if echo "$line" | grep -q "TCP6-LISTEN"; then
			# 提取 externalPort (来自 TCP6-LISTEN:xxxx)
			externalPort=$(echo "$line" | sed -n 's/.*TCP6-LISTEN:\([0-9]*\).*/\1/p')
			# 提取 internalAddress 和 internalPort (来自 TCP4:internalAddress:internalPort)
			internalAddress=$(echo "$line" | sed -n 's/.*TCP4:\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\:.*/\1/p')
			internalPort=$(echo "$line" | sed -n 's/.*TCP4:[0-9\.]*:\([0-9]*\).*/\1/p')
			protocol="TCP"
			# 构建 JSON 数据
			local id$id=$(json_output id:int externalPort:str internalAddress:str internalPort:str protocol:str)
			json_append __json_result__ id$id:json


			fi
		
		  if echo "$line" | grep -q "UDP6-LISTEN"; then
            # 提取 externalPort (来自 UDP6-LISTEN:xxxx)
            externalPort=$(echo "$line" | sed -n 's/.*UDP6-LISTEN:\([0-9]*\).*/\1/p')
            # 提取 internalAddress 和 internalPort (来自 UDP4:internalAddress:internalPort)
            internalAddress=$(echo "$line" | sed -n 's/.*UDP4:\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\:.*/\1/p')
            internalPort=$(echo "$line" | sed -n 's/.*UDP4:[0-9\.]*:\([0-9]*\).*/\1/p')
			protocol="UDP"
            # 构建 JSON 数据
            local id$id=$(json_output id:int externalPort:str internalAddress:str internalPort:str protocol:str)
            json_append __json_result__ id$id:json

        fi
		

	 id=$((id + 1))
    done < /etc/mnt/socat.conf
}



delete_config() {

    # 提取等号右边的值，真正的 ID
    local id=$(echo "$1" | cut -d '=' -f 2)

    local line_num=$id
    # 读取指定行号的内容
    local line_content=$(sed -n "${line_num}p" /etc/mnt/socat.conf)

    # 提取与 socat 相关的部分，如 TCP6-LISTEN:8080
    local socat_match=$(echo "$line_content" | grep -o 'TCP6-LISTEN:[0-9]*\|UDP6-LISTEN:[0-9]*\|SCTP6-LISTEN:[0-9]*')

    if [ -n "$socat_match" ]; then
        # 使用 ps | grep 查找对应的进程 ID
        local pids=$(ps | grep "$socat_match" | grep -v "grep" | awk '{print $1}')

        # 终止找到的进程
        for pid in $pids; do
            kill -9 $pid
        done
    fi

    # 删除指定行号的配置
    sed -i "${line_num}d" /etc/mnt/socat.conf

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
