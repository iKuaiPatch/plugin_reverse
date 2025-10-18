#!/bin/bash 
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
. /etc/mnt/plugins/configs/config.sh

start() {

    if [ -f $EXT_PLUGIN_CONFIG_DIR/socat/socat.conf ]; then
        bash $EXT_PLUGIN_CONFIG_DIR/socat/socat.conf >/dev/null &
    fi
}

stop() {

    killall socat >/dev/null
}

show() {

    Show __json_result__
}

__show_status() {

    local status=0

    if killall -q -0 socat; then
        local status=1
    fi

    json_append __json_result__ status:int

}

add_config() {
    rm /tmp/socat.log
    # 调试：输出传递的参数
    echo "All Parameters: $@" >>/tmp/socat.log

    # 提取每个参数的值
    for param in "$@"; do
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

    if [ $protocol == "TCP" ]; then
        echo "socat TCP6-LISTEN:$externalPort,fork,reuseaddr TCP4:$internalAddress:$internalPort >/dev/null &" >>$EXT_PLUGIN_CONFIG_DIR/socat/socat.conf
        socat TCP6-LISTEN:$externalPort,fork,reuseaddr TCP4:$internalAddress:$internalPort >/dev/null &
    fi

    if [ $protocol == "UDP" ]; then
        echo "socat UDP6-LISTEN:$externalPort,fork,reuseaddr UDP4:$internalAddress:$internalPort >/dev/null &" >>$EXT_PLUGIN_CONFIG_DIR/socat/socat.conf
        socat UDP6-LISTEN:$externalPort,fork,reuseaddr UDP4:$internalAddress:$internalPort >/dev/null &
    fi

}

__show_configs() {
    id=1
    # 逐行读取配置文件
    while IFS= read -r line; do
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
    done <$EXT_PLUGIN_CONFIG_DIR/socat/socat.conf
}

delete_config() {

    # 提取等号右边的值，真正的 ID
    local id=$(echo "$1" | cut -d '=' -f 2)

    local line_num=$id
    # 读取指定行号的内容
    local line_content=$(sed -n "${line_num}p" $EXT_PLUGIN_CONFIG_DIR/socat/socat.conf)

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
    sed -i "${line_num}d" $EXT_PLUGIN_CONFIG_DIR/socat/socat.conf

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
